"""Test QQ Music credential refresh and liked-song write requests.

The cookie is read from QQMUSIC_COOKIE or prompted without echoing it. Do not
commit or share cookies or full responses because they contain login secrets.
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from http.cookies import SimpleCookie
from typing import Any

API_URL = "https://u.y.qq.com/cgi-bin/musicu.fcg"


def parse_cookie(raw: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for part in raw.replace("\r", "").replace("\n", "").split(";"):
        if "=" not in part:
            continue
        name, value = part.strip().split("=", 1)
        if name:
            result[name] = value
    return result


def cookie_header(cookie: dict[str, str]) -> str:
    return "; ".join(f"{name}={value}" for name, value in cookie.items() if value)


def first(cookie: dict[str, str], *names: str) -> str:
    return next((cookie[name] for name in names if cookie.get(name)), "")


def hash33(value: str, seed: int = 0) -> int:
    result = seed
    for byte in value.encode("utf-8"):
        result += (result << 5) + byte
    return result & 0x7FFFFFFF


def as_int(value: str) -> int:
    try:
        return int(value)
    except ValueError:
        return 0


def fingerprint(value: str) -> str:
    if not value:
        return "<empty>"
    return hashlib.sha256(value.encode()).hexdigest()[:12]


def credential_values(cookie: dict[str, str]) -> tuple[str, str, int]:
    music_id = first(cookie, "musicid", "qqmusic_uin", "uin")
    music_key = first(cookie, "musickey", "qm_keyst", "qqmusic_key")
    login_type = as_int(first(cookie, "login_type", "loginType", "tmeLoginType"))
    if login_type == 0:
        login_type = 1 if music_key.startswith("W_X") else 2
    if not music_id or not music_key:
        raise ValueError(
            "Cookie 缺少 musicid/qqmusic_uin 或 musickey/qm_keyst/qqmusic_key"
        )
    return music_id, music_key, login_type


def create_request_signature(payload: str) -> str:
    part1_indexes = (23, 14, 6, 36, 16, 7, 19)
    part2_indexes = (16, 1, 32, 12, 19, 27, 8, 5)
    scramble_values = (
        89, 39, 179, 150, 218, 82, 58, 252, 177, 52,
        186, 123, 120, 64, 242, 133, 143, 161, 121, 179,
    )
    digest = hashlib.sha1(payload.encode()).digest()
    digest_hex = digest.hex().upper()
    part1 = "".join(digest_hex[index] for index in part1_indexes)
    part2 = "".join(digest_hex[index] for index in part2_indexes)
    import base64

    encoded = base64.b64encode(
        bytes(value ^ digest[index] for index, value in enumerate(scramble_values))
    ).decode()
    encoded = "".join(char for char in encoded if char not in "/+=\\")
    return f"zzc{part1}{encoded}{part2}".lower()


def build_qqconnect_refresh_request(
    cookie: dict[str, str],
) -> tuple[dict[str, Any], str]:
    music_id, music_key, _ = credential_values(cookie)
    return {
        "comm": {
            "ct": 24,
            "cv": 4747474,
            "platform": "yqq.json",
            "uin": as_int(music_id),
            "format": "json",
            "inCharset": "utf-8",
            "outCharset": "utf-8",
            "tmeLoginType": 2,
        },
        "req_0": {
            "module": "QQConnectLogin.LoginServer",
            "method": "QQLogin",
            "param": {
                "expired_in": 7776000,
                "musicid": as_int(music_id),
                "musickey": music_key,
            },
        },
    }, music_key


def build_refresh_request(cookie: dict[str, str]) -> tuple[dict[str, Any], str]:
    music_id, music_key, login_type = credential_values(cookie)
    params: dict[str, Any] = {
        "openid": first(cookie, "openid", "psrf_qqopenid"),
        "access_token": first(cookie, "access_token", "psrf_qqaccess_token"),
        "refresh_token": first(cookie, "refresh_token", "psrf_qqrefresh_token"),
        "expired_in": as_int(first(cookie, "expired_at", "expired_in")),
        "str_musicid": first(cookie, "str_musicid") or music_id,
        "musicid": as_int(music_id),
        "musickey": music_key,
        "unionid": first(cookie, "unionid"),
        "refresh_key": first(cookie, "refresh_key"),
        "loginMode": 2,
    }
    if login_type == 1:
        params.pop("access_token")
        params.pop("expired_in")
        params.pop("musicid")
    elif login_type == 2:
        params.pop("str_musicid")
        params.pop("unionid")

    token = hash33(music_key, 5381)
    return {
        "comm": {
            "ct": 24,
            "cv": 4747474,
            "platform": "yqq.json",
            "chid": "0",
            "uin": as_int(music_id),
            "g_tk": token,
            "g_tk_new_20200303": token,
            "format": "json",
            "inCharset": "utf-8",
            "outCharset": "utf-8",
            "notice": 0,
            "needNewCode": 1,
            "tmeLoginType": login_type,
        },
        "req_0": {
            "module": "music.login.LoginServer",
            "method": "Login",
            "param": params,
        },
    }, music_key


def build_liked_request(
    cookie: dict[str, str], song_id: int, *, liked: bool
) -> dict[str, Any]:
    music_id, music_key, login_type = credential_values(cookie)
    return {
        "comm": {
            "ct": "11",
            "cv": 13020508,
            "v": 13020508,
            "tmeAppID": "qqmusic",
            "uid": music_id,
            "qq": music_id,
            "authst": music_key,
            "tmeLoginType": str(login_type),
            "loginUin": music_id,
        },
        "req_0": {
            "module": "music.musicasset.PlaylistDetailWrite",
            "method": "AddSonglist" if liked else "DelSonglist",
            "param": {
                "dirId": 201,
                "tid": 0,
                "bFmtUtf8": True,
                "v_songInfo": [{"songId": song_id, "songType": 0}],
            },
        },
    }


def post(
    payload: dict[str, Any], cookie: dict[str, str], *, signed: bool = False
) -> tuple[dict[str, Any], dict[str, str]]:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    url = API_URL
    if signed:
        from urllib.parse import urlencode

        url = f"https://u6.y.qq.com/cgi-bin/musics.fcg?{urlencode({'sign': create_request_signature(body)})}"
    request = urllib.request.Request(
        url,
        data=body.encode(),
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json; charset=utf-8",
            "Cookie": cookie_header(cookie),
            "Origin": "https://y.qq.com",
            "Referer": "https://y.qq.com/",
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw_response = response.read().decode("utf-8", errors="replace")
            response_cookies: dict[str, str] = {}
            for raw_set_cookie in response.headers.get_all("Set-Cookie") or []:
                parsed_cookie = SimpleCookie()
                parsed_cookie.load(raw_set_cookie)
                response_cookies.update(
                    {name: morsel.value for name, morsel in parsed_cookie.items()}
                )
    except urllib.error.HTTPError as error:
        raw_response = error.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {raw_response}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"请求失败：{error}") from error
    try:
        decoded = json.loads(raw_response)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"响应不是 JSON：{raw_response}") from error
    if not isinstance(decoded, dict):
        raise RuntimeError(f"响应根节点不是对象：{raw_response}")
    return decoded, response_cookies


def response_data(result: dict[str, Any]) -> dict[str, Any]:
    item = result.get("req_0")
    if not isinstance(item, dict):
        return {}
    data = item.get("data")
    if not isinstance(data, dict):
        return {}
    nested = data.get("data") if "code" in data else data
    return nested if isinstance(nested, dict) else {}


def print_response(
    title: str, result: dict[str, Any], *, full_response: bool = False
) -> bool:
    if full_response:
        print(f"\n{title}完整响应（可能包含敏感信息，请勿分享）：")
        print(json.dumps(result, ensure_ascii=False, indent=2))
    item = result.get("req_0")
    data = item.get("data") if isinstance(item, dict) else None
    print(f"\n{title}摘要：")
    print(f"outer code: {result.get('code')}")
    print(f"req_0 code: {item.get('code') if isinstance(item, dict) else None}")
    effective = False
    if isinstance(data, dict):
        result_data = data.get("result")
        print(f"data code: {data.get('code')}")
        print(f"retCode: {data.get('retCode')}")
        print(f"result: {result_data}")
        if title.startswith(("添加我喜欢", "取消我喜欢")):
            effective = (
                item.get("code") == 0
                and data.get("retCode") == 0
                and isinstance(result_data, dict)
                and result_data.get("dirId") == 201
                and bool(result_data.get("tid"))
                and bool(result_data.get("updateTime"))
            )
            print(f"写入真正生效: {effective}")
    return effective


def qqconnect_refresh(
    cookie: dict[str, str], *, full_response: bool = False
) -> tuple[dict[str, Any], dict[str, str]]:
    payload, old_key = build_qqconnect_refresh_request(cookie)
    result, response_cookies = post(payload, cookie, signed=True)
    print_response("QQConnect 续期", result, full_response=full_response)
    refreshed = response_data(result)
    new_key = str(refreshed.get("musickey") or "")
    print(f"旧 musickey 指纹: {fingerprint(old_key)}")
    print(f"响应包含 musickey: {bool(new_key)}")
    print(f"新 musickey 指纹: {fingerprint(new_key)}")
    print(f"musickey 已变化: {bool(new_key) and new_key != old_key}")
    print(f"Set-Cookie 更新字段: {sorted(response_cookies)}")
    return refreshed, response_cookies


def refresh(
    cookie: dict[str, str], *, full_response: bool = False
) -> tuple[dict[str, Any], dict[str, str]]:
    payload, old_key = build_refresh_request(cookie)
    params = payload["req_0"]["param"]
    missing = [
        name
        for name in ("openid", "refresh_token", "refresh_key")
        if not params.get(name)
    ]
    if missing:
        print(f"警告：Cookie 缺少续期字段：{', '.join(missing)}", file=sys.stderr)

    result, response_cookies = post(payload, cookie)
    print_response("续期", result, full_response=full_response)
    refreshed = response_data(result)
    new_key = str(refreshed.get("musickey") or "")
    print(f"旧 musickey 指纹: {fingerprint(old_key)}")
    print(f"响应包含 musickey: {bool(new_key)}")
    print(f"新 musickey 指纹: {fingerprint(new_key)}")
    print(f"musickey 已变化: {bool(new_key) and new_key != old_key}")
    print(
        "musickeyCreateTime: "
        f"{refreshed.get('musickeyCreateTime', refreshed.get('musickey_create_time'))}"
    )
    print(
        "keyExpiresIn: "
        f"{refreshed.get('keyExpiresIn', refreshed.get('key_expires_in'))}"
    )
    print(f"Set-Cookie 更新字段: {sorted(response_cookies)}")
    return refreshed, response_cookies


def merge_refreshed_cookie(
    cookie: dict[str, str],
    refreshed: dict[str, Any],
    response_cookies: dict[str, str],
) -> dict[str, str]:
    merged = {**cookie, **response_cookies}
    aliases = {
        "musicid": ("musicid", "qqmusic_uin"),
        "musickey": ("musickey", "qm_keyst", "qqmusic_key"),
        "openid": ("openid",),
        "refresh_token": ("refresh_token",),
        "access_token": ("access_token",),
        "expired_at": ("expired_at",),
        "unionid": ("unionid",),
        "str_musicid": ("str_musicid",),
        "refresh_key": ("refresh_key",),
        "encrypt_uin": ("encrypt_uin", "encryptUin"),
        "login_type": ("login_type", "loginType"),
    }
    for target, names in aliases.items():
        value = next(
            (refreshed[name] for name in names if refreshed.get(name) is not None),
            None,
        )
        if value is not None and str(value):
            merged[target] = str(value)
    if merged.get("musickey"):
        merged["qm_keyst"] = merged["musickey"]
        merged["qqmusic_key"] = merged["musickey"]
    if merged.get("musicid"):
        merged["qqmusic_uin"] = merged["musicid"]
    if merged.get("openid"):
        merged["psrf_qqopenid"] = merged["openid"]
    if merged.get("refresh_token"):
        merged["psrf_qqrefresh_token"] = merged["refresh_token"]
    if merged.get("access_token"):
        merged["psrf_qqaccess_token"] = merged["access_token"]
    return merged


def minimal_cookie(cookie: dict[str, str]) -> dict[str, str]:
    names = (
        "musicid",
        "musickey",
        "qm_keyst",
        "qqmusic_key",
        "qqmusic_uin",
        "login_type",
    )
    return {name: cookie[name] for name in names if cookie.get(name)}


def write_liked(
    cookie: dict[str, str],
    song_id: int,
    *,
    liked: bool,
    full_response: bool = False,
    label: str = "",
) -> bool:
    action = "添加我喜欢" if liked else "取消我喜欢"
    title = f"{action}{label}"
    _, music_key, _ = credential_values(cookie)
    print(f"\n{title}使用的 musickey 指纹: {fingerprint(music_key)}")
    result, _ = post(build_liked_request(cookie, song_id, liked=liked), cookie)
    return print_response(title, result, full_response=full_response)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="测试 QQ 音乐凭据续期以及添加/取消我喜欢请求"
    )
    parser.add_argument(
        "action", choices=("refresh", "qq-refresh", "like", "unlike")
    )
    parser.add_argument("song_id", type=int, nargs="?", help="歌曲的数字 songId")
    parser.add_argument(
        "--refresh-first",
        choices=("login", "qqconnect"),
        help="写入前先续期：login 使用 LoginServer，qqconnect 使用签名 QQLogin",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0,
        help="续期后首次写入前等待秒数",
    )
    parser.add_argument(
        "--retry-delays",
        type=float,
        nargs="*",
        default=[],
        help="首次失败后使用同一新 key 再次写入前依次等待的秒数",
    )
    parser.add_argument(
        "--minimal-cookie",
        action="store_true",
        help="写入时仅发送 musicid/musickey 等必要 Cookie",
    )
    parser.add_argument(
        "--full-response",
        action="store_true",
        help="输出包含敏感信息的完整响应（默认只输出摘要）",
    )
    args = parser.parse_args()
    if args.action in ("like", "unlike") and args.song_id is None:
        parser.error("like/unlike 必须提供歌曲数字 ID")
    if args.action in ("refresh", "qq-refresh") and args.refresh_first:
        parser.error("refresh 动作不能与 --refresh-first 同时使用")
    return args


def main() -> int:
    args = arguments()
    raw_cookie = os.environ.get("QQMUSIC_COOKIE", "").strip()
    if not raw_cookie:
        raw_cookie = getpass.getpass("粘贴 QQ 音乐 Cookie（输入不会显示）: ").strip()
    if not raw_cookie:
        print("未提供 Cookie", file=sys.stderr)
        return 2

    cookie = parse_cookie(raw_cookie)
    try:
        credential_values(cookie)
        if args.action == "refresh":
            refresh(cookie, full_response=args.full_response)
            return 0
        if args.action == "qq-refresh":
            qqconnect_refresh(cookie, full_response=args.full_response)
            return 0
        refreshed_at = time.monotonic()
        if args.refresh_first:
            refreshed, response_cookies = (
                refresh(cookie, full_response=args.full_response)
                if args.refresh_first == "login"
                else qqconnect_refresh(cookie, full_response=args.full_response)
            )
            cookie = merge_refreshed_cookie(cookie, refreshed, response_cookies)
            if not refreshed.get("musickey"):
                print(
                    "续期响应没有 musickey，已停止写入，避免误用旧 key。",
                    file=sys.stderr,
                )
                return 1
            refreshed_at = time.monotonic()
        if args.minimal_cookie:
            cookie = minimal_cookie(cookie)
            print(f"写入 Cookie 模式: 精简（字段：{sorted(cookie)}）")
        else:
            print("写入 Cookie 模式: 完整")
        if args.delay > 0:
            print(f"首次写入前等待: {args.delay:g} 秒")
            time.sleep(args.delay)
        attempts = [0, *args.retry_delays]
        effective = False
        for index, retry_delay in enumerate(attempts, start=1):
            if index > 1 and retry_delay > 0:
                print(f"第 {index} 次写入前等待: {retry_delay:g} 秒")
                time.sleep(retry_delay)
            elapsed = time.monotonic() - refreshed_at
            print(f"写入尝试 {index}（续期后 {elapsed:.1f} 秒）")
            effective = write_liked(
                cookie,
                args.song_id,
                liked=args.action == "like",
                full_response=args.full_response,
                label=f"（第 {index} 次）",
            )
            if effective:
                break
        return 0 if effective else 3
    except (ValueError, RuntimeError) as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
