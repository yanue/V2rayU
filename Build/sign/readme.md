### 生成新的签名 crt

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -config V2rayU-openssl.cnf -keyout V2rayU.key -out V2rayU.crt
```

### 导入 crt 和 key 到 Keychain

```bash
security import V2rayU.crt -k ~/Library/Keychains/login.keychain
security import V2rayU.key -k ~/Library/Keychains/login.keychain
```

### 信任刚导入的 crt 

```bash
security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain V2rayU.crt
```

### 查看 crt 是否导入成功
```bash
security find-identity -p codesigning
```

### 签名应用和 dmg

```bash
codesign --force --deep --sign "V2rayU" ./V2rayU.app
codesign --sign "V2rayU" V2rayU.dmg
```

### 验证签名

```bash
codesign -v ./V2rayU.app
```

### 局限
一直弹窗提醒,很麻烦
Apple could not verify “V2rayU” is free of malware that may harm your Mac or compromise your privacy.

