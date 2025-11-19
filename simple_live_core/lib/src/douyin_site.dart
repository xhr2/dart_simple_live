import 'dart:convert';
import 'dart:math';

import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/convert_helper.dart';
import 'package:simple_live_core/src/common/http_client.dart';

class DouyinSite implements LiveSite {
  @override
  String id = "douyin";

  @override
  String name = "抖音直播";

  @override
  LiveDanmaku getDanmaku() =>
      DouyinDanmaku()..setSignatureFunction(getSignature);

  Future<String> Function(String, String) getAbogusUrl =
      (url, userAgent) async {
    throw Exception(
        "You must call setAbogusUrlFunction to set the function first");
  };

  void setAbogusUrlFunction(Future<String> Function(String, String) func) {
    getAbogusUrl = func;
  }

  Future<String> Function(String, String) getSignature =
      (roomId, uniqueId) async {
    throw Exception(
        "You must call setSignatureFunction to set the function first");
  };

  void setSignatureFunction(Future<String> Function(String, String) func) {
    getSignature = func;
  }

  static const String kDefaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.0.0";

  static const String kDefaultReferer = "https://live.douyin.com";

  static const String kDefaultAuthority = "live.douyin.com";

  Map<String, dynamic> headers = {
    "Authority": kDefaultAuthority,
    "Referer": kDefaultReferer,
    "User-Agent": kDefaultUserAgent,
  };

  /// ================================
  /// 新增：获取 ttwid
  /// ================================
  Future<String> fetchTTwid() async {
    final url = 'https://ttwid.bytedance.com/ttwid/union/register/';
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.102 Safari/537.36 NetType/WIFI MicroMessenger/7.0.20.1781(0x6700143B) WindowsWechat(0x63090551) XWEB/6939 Flue',
      'Content-Type': 'application/json',
    };
    final data = {
      "region": "cn",
      "aid": 1768,
      "needFid": false,
      "service": "www.ixigua.com",
      "migrate_info": {"ticket": "", "source": "node"},
      "cbUrlProtocol": "https",
      "union": true
    };

    try {
      var resp = await HttpClient.instance.post(
        url,
        data: json.encode(data),
        header: headers,
      );

      var setCookie = resp.headers['set-cookie'];
      if (setCookie != null) {
        for (var cookie in setCookie) {
          if (cookie.contains('ttwid=')) {
            var ttwidValue = cookie.split('=')[1].split(';')[0];
            return 'ttwid=$ttwidValue';
          }
        }
      }
    } catch (e) {
      throw Exception('获取 ttwid 失败: $e');
    }

    throw Exception('ttwid 未获取到');
  }

  /// 统一获取 cookie
  Future<String> _getWebCookie(String webRid) async {
    // 目前只使用 ttwid
    return await fetchTTwid();
  }

  /// ================================
  /// 下面保持原来的 DouyinSite 逻辑，GET/POST 请求统一使用 _getWebCookie()
  /// ================================

  Future<Map<String, dynamic>> getRequestHeaders() async {
    try {
      var cookie = await _getWebCookie("");
      return {
        "Authority": kDefaultAuthority,
        "Referer": kDefaultReferer,
        "User-Agent": kDefaultUserAgent,
        "Cookie": cookie,
      };
    } catch (e) {
      CoreLog.error(e);
      return headers;
    }
  }

  @override
  Future<List<LiveCategory>> getCategores() async {
    List<LiveCategory> categories = [];
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/",
      queryParameters: {},
      header: await getRequestHeaders(),
    );

    var renderData =
        RegExp(r'\{\\"pathname\\":\\"\/\\",\\"categoryData.*?\]\\n')
                .firstMatch(result)
                ?.group(0) ??
            "";
    var renderDataJson = json.decode(renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', ""));

    for (var item in renderDataJson["categoryData"]) {
      List<LiveSubCategory> subs = [];
      var id = '${item["partition"]["id_str"]},${item["partition"]["type"]}';
      for (var subItem in item["sub_partition"]) {
        var subCategory = LiveSubCategory(
          id: '${subItem["partition"]["id_str"]},${subItem["partition"]["type"]}',
          name: asT<String?>(subItem["partition"]["title"]) ?? "",
          parentId: id,
          pic: "",
        );
        subs.add(subCategory);
      }

      var category = LiveCategory(
        children: subs,
        id: id,
        name: asT<String?>(item["partition"]["title"]) ?? "",
      );
      subs.insert(
          0,
          LiveSubCategory(
            id: category.id,
            name: category.name,
            parentId: category.id,
            pic: "",
          ));
      categories.add(category);
    }
    return categories;
  }

  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    if (roomId.length <= 16) {
      var webRid = roomId;
      return await getRoomDetailByWebRid(webRid);
    }
    return await getRoomDetailByRoomId(roomId);
  }

  Future<LiveRoomDetail> getRoomDetailByRoomId(String roomId) async {
    var roomData = await _getRoomDataByRoomId(roomId);
    var webRid = roomData["data"]["room"]["owner"]["web_rid"].toString();
    var userUniqueId = generateRandomNumber(12).toString();
    var room = roomData["data"]["room"];
    var owner = room["owner"];
    var status = asT<int?>(room["status"]) ?? 0;

    if (status == 4) {
      return await getRoomDetailByWebRid(webRid);
    }

    var roomStatus = status == 2;
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: room["title"].toString(),
      cover: roomStatus ? room["cover"]["url_list"][0].toString() : "",
      userName: owner["nickname"].toString(),
      userAvatar: owner["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(room["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner["signature"].toString(),
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["Cookie"],
      ),
      data: room["stream_url"],
    );
  }

  Future<LiveRoomDetail> getRoomDetailByWebRid(String webRid) async {
    try {
      var result = await _getRoomDetailByWebRidApi(webRid);
      return result;
    } catch (e) {
      CoreLog.error(e);
    }
    return await _getRoomDetailByWebRidHtml(webRid);
  }

  Future<LiveRoomDetail> _getRoomDetailByWebRidApi(String webRid) async {
    var data = await _getRoomDataByApi(webRid);
    var roomData = data["data"][0];
    var userData = data["user"];
    var roomId = roomData["id_str"].toString();
    var userUniqueId = generateRandomNumber(12).toString();
    var owner = roomData["owner"];
    var roomStatus = (asT<int?>(roomData["status"]) ?? 0) == 2;
    var headers = await getRequestHeaders();

    return LiveRoomDetail(
      roomId: webRid,
      title: roomData["title"].toString(),
      cover: roomStatus ? roomData["cover"]["url_list"][0].toString() : "",
      userName: roomStatus
          ? owner["nickname"].toString()
          : userData["nickname"].toString(),
      userAvatar: roomStatus
          ? owner["avatar_thumb"]["url_list"][0].toString()
          : userData["avatar_thumb"]["url_list"][0].toString(),
      online: roomStatus
          ? asT<int?>(roomData["room_view_stats"]["display_value"]) ?? 0
          : 0,
      status: roomStatus,
      url: "https://live.douyin.com/$webRid",
      introduction: owner?["signature"]?.toString() ?? "",
      notice: "",
      danmakuData: DouyinDanmakuArgs(
        webRid: webRid,
        roomId: roomId,
        userId: userUniqueId,
        cookie: headers["Cookie"],
      ),
      data: roomStatus ? roomData["stream_url"] : {},
    );
  }

  Future<Map> _getRoomDataByHtml(String webRid) async {
    var dyCookie = await _getWebCookie(webRid);
    var result = await HttpClient.instance.getText(
      "https://live.douyin.com/$webRid",
      queryParameters: {},
      header: {
        "Authority": kDefaultAuthority,
        "Referer": kDefaultReferer,
        "Cookie": dyCookie,
        "User-Agent": kDefaultUserAgent,
      },
    );

    var renderData = RegExp(r'\{\\"state\\":\{\\"appStore.*?\]\\n')
            .firstMatch(result)
            ?.group(0) ??
        "";
    var str = renderData
        .trim()
        .replaceAll('\\"', '"')
        .replaceAll(r"\\", r"\")
        .replaceAll(']\\n', "");
    var renderDataJson = json.decode(str);
    return renderDataJson["state"];
  }

  Future<Map> _getRoomDataByApi(String webRid) async {
    String serverUrl = "https://live.douyin.com/webcast/room/web/enter/";
    var uri = Uri.parse(serverUrl).replace(queryParameters: {
      "aid": '6383',
      "app_name": "douyin_web",
      "device_platform": "web",
      "web_rid": webRid,
    });

    var requestUrl = await getAbogusUrl(uri.toString(), kDefaultUserAgent);
    var headers = await getRequestHeaders();
    var result = await HttpClient.instance.getJson(
      requestUrl,
      header: headers,
    );
    return result["data"];
  }

  Future<Map> _getRoomDataByRoomId(String roomId) async {
    var headers = await getRequestHeaders();
    var result = await HttpClient.instance.getJson(
      'https://webcast.amemv.com/webcast/room/reflow/info/',
      queryParameters: {
        "type_id": 0,
        "live_id": 1,
        "room_id": roomId,
        "sec_user_id": "",
        "version_code": "99.99.99",
        "app_id": 6383,
      },
      header: headers,
    );
    return result;
  }

  /// 生成随机数字
  int generateRandomNumber(int length) {
    var random = Random.secure();
    var values = List<int>.generate(length, (i) => random.nextInt(10));
    StringBuffer stringBuffer = StringBuffer();
    for (var item in values) {
      stringBuffer.write(item);
    }
    return int.tryParse(stringBuffer.toString()) ?? Random().nextInt(1000000000);
  }
}
