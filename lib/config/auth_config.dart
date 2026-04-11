/// Authentication configuration for YouTube Music API
/// 
/// To get your session cookie:
/// 1. Go to https://music.youtube.com in your browser
/// 2. Open DevTools (F12)
/// 3. Go to Application > Cookies > music.youtube.com
/// 4. Copy the value of the 'SAPISID' and 'APISID' cookies
/// 5. Or use the full cookie header from Network requests
/// 
class AuthConfig {
  // AUTHENTICATED SESSION COOKIE - Updated April 5, 2026
  static const String sessionCookie = 'VISITOR_INFO1_LIVE=HWsFkgFXbcw; VISITOR_PRIVACY_METADATA=CgJaQRIEGgAgJg%3D%3D; LOGIN_INFO=AFmmF2swRAIgOz73wjYAsxa_-TuuakB5b6wJNqc06syMzeT7Cv8lmHgCIHyNvgaDvP1fzX2F6BAOfHvzCiRTL8ClhkG-_ulcFA2e:QUQ3MjNmejhQVG9aVm5NZkZiWWtjeTZ1ZWRiOGVtdEt3RG5YYWJtUGxmUWdyRldUenhHZ1hOdmEwTGN2cGVpQlhUcnFpbkdtMmV2SHhkMmZJRUlmczJfcmo1U2w0VWNSMVJLcEluNXFTQXJiR3NwMXUxc2dJVkt4RHdES1c5UENXbVVBNzllMjJuQVhoLVB0NmFQQzJBTGx5S3hTbEpxUHJB; HSID=AjQnSqr5ux6jgeECa; SSID=AMsQ7PqjR2lZYROwV; APISID=Cyq5YmfZrOUDBbBN/AQucLdMPV8h4flP_P; SAPISID=t1fx2TIIefzpml7W/A2CUTd7FbRv7Rm8g9; __Secure-1PAPISID=t1fx2TIIefzpml7W/A2CUTd7FbRv7Rm8g9; __Secure-3PAPISID=t1fx2TIIefzpml7W/A2CUTd7FbRv7Rm8g9; SID=g.a0008AhwvcJRKMwu-2ZIAqGJWCcmKdRVCV4pCa4J9TSH8Z-ZM9BgVCpcbrpOWkdoH8DahneeOwACgYKAWoSARcSFQHGX2Mi3chxAhUlmGGGwAIZkWOBLRoVAUF8yKpA42fwnRUyPmh4AmBYLFri0076; __Secure-1PSID=g.a0008AhwvcJRKMwu-2ZIAqGJWCcmKdRVCV4pCa4J9TSH8Z-ZM9Bg73xn97qB9efHu-RLvsT6ugACgYKAVcSARcSFQHGX2MiDssFpqkR8gIqehh1oQYVcBoVAUF8yKqBIptgCxUNs7yHM3Glw2E90076; __Secure-3PSID=g.a0008AhwvcJRKMwu-2ZIAqGJWCcmKdRVCV4pCa4J9TSH8Z-ZM9BgEFXM7ZGhX5MWe5c1szZtiAACgYKAfcSARcSFQHGX2Mi05-V6vgzeV8FmKolAxjp0RoVAUF8yKpuIul07oEBAWJPDZmq9gOw0076; PREF=tz=Africa.Johannesburg&f7=100&f6=40000000&f4=4000000; __Secure-ROLLOUT_TOKEN=CKHUq6Hg4vadWBDCwtr-7ZKQAxjnia_J4NSTAw%3D%3D; __Secure-1PSIDTS=sidts-CjUBWhotCdVVBHwVqfOJ3h3rJESe1STgPctUizoQqbkfsVPElISZDO-ocHP3DMlGNg75uAl81hAA; __Secure-3PSIDTS=sidts-CjUBWhotCdVVBHwVqfOJ3h3rJESe1STgPctUizoQqbkfsVPElISZDO-ocHP3DMlGNg75uAl81hAA; YSC=sJ6PtTNrxE4; _gcl_au=1.1.1542144204.1775398171; SIDCC=AKEyXzWPkiscvBd3Q1zX0u8OggU672tlCM6dIcMk6nL5kZru7netw4HqDL4Zq-FftFHSVCA1JQ; __Secure-1PSIDCC=AKEyXzULCGuYipTj85oTsWTj2jHApNeIHqFlZkm2HByowJGu9UYPTXmBun4ss0fe_DPXvCQhSA; __Secure-3PSIDCC=AKEyXzVOyVvAfiRB4k3yb2Sv1ycVjyShR0LosOmtjDuZQyULPfnuPkv4fGpP3_SbJgl7kqWe7w';
  
  // Authorization header with SAPISIDHASH tokens
  static const String authorizationHeader = 'SAPISIDHASH 1775398857_856f4ef5236f1f91bd5f47fb3782d3e9bbb34269_u SAPISID1PHASH 1775398857_856f4ef5236f1f91bd5f47fb3782d3e9bbb34269_u SAPISID3PHASH 1775398857_856f4ef5236f1f91bd5f47fb3782d3e9bbb34269_u';
  
  // X-Goog-AuthUser header
  static const String xGoogAuthUser = '0';
  
  // Origin header
  static const String origin = 'https://music.youtube.com';
  
  // Standard Chrome User-Agent - Windows 10 (matches browser cookie was extracted from)
  static const String userAgent = 
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Safari/537.36';
  
  // Alternative Firefox User-Agent
  static const String userAgentFirefox =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) '
    'Gecko/20100101 Firefox/121.0';
  
  /// Returns true if authentication is configured
  static bool get isConfigured => sessionCookie != 'YOUR_SESSION_COOKIE_HERE';
  
  /// Validate that the cookie is properly configured
  static String validateConfiguration() {
    if (!isConfigured) {
      return '''
AUTHENTICATION NOT CONFIGURED!

To enable YouTube Music API access:
1. Open https://music.youtube.com in your browser
2. Open DevTools (F12) > Application > Cookies
3. Copy the "SAPISID" or full cookie header
4. Paste it into lib/config/auth_config.dart as sessionCookie
5. Rebuild the app

Without this, the app will continue to use mock data.
      ''';
    }
    return 'Authentication configured successfully';
  }
}
