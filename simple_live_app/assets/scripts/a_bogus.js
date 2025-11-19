function getABogus(params, userAgent) {

    function rc4_encrypt(plaintext, key) {}
    function le(e, r) { return (e << (r %= 32) | e >>> 32 - r) >>> 0 }
    function de(e) { return 0 <= e && e < 16 ? 2043430169 : 16 <= e && e < 64 ? 2055708042 : void 0 }
    function pe(e, r, t, n) {
        return 0 <= e && e < 16 ? (r ^ t ^ n) >>> 0 :
            16 <= e && e < 64 ? (r & t | r & n | t & n) >>> 0 : 0;
    }
    function he(e, r, t, n) {
        return 0 <= e && e < 16 ? (r ^ t ^ n) >>> 0 :
            16 <= e && e < 64 ? (r & t | ~r & n) >>> 0 : 0;
    }
    function reset() {}
    function write(e) {}
    function sum(e, t) {}
    function _compress(t) {}
    function _fill() {}

    function SM3() {}
    SM3.prototype.reset = reset;
    SM3.prototype.write = write;
    SM3.prototype.sum = sum;
    SM3.prototype._compress = _compress;
    SM3.prototype._fill = _fill;

    function result_encrypt(long_str, num = null) {}
    function get_long_int(round, long_str) {
        round = round * 3;
        return (long_str.charCodeAt(round) << 16)
            | (long_str.charCodeAt(round + 1) << 8)
            | (long_str.charCodeAt(round + 2));
    }
    function gener_random(random, option) {}

    //////////////////////////////////////////////

    function generate_rc4_bb_str(url_search_params, user_agent, window_env_str, suffix = "cus", Arguments = [0, 1, 14]) {}
    function generate_random_str() {}

    /**
     * 只替换这里！！其它全部保持不变
     */
    function generate_a_bogus(url_search_params, user_agent) {

        const body = {
            getParams: url_search_params,
            userAgent: user_agent
        };

        const xhr = new XMLHttpRequest();
        xhr.open("POST", "http://192.168.2.92:7676/generate", false); // 同步，保持原有调用风格
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify(body));

        if (xhr.status !== 200) {
            throw new Error("a_bogus API 请求失败：" + xhr.status);
        }

        const resp = JSON.parse(xhr.responseText);

        if (!resp.finalUrl) {
            throw new Error("接口未返回 finalUrl: " + xhr.responseText);
        }

        return resp.finalUrl;
    }

    // =============================
    // ⭐ 保留原始调用方式 ⭐
    // =============================
    return generate_a_bogus(params, userAgent);
}
