# Path Oracle 🌊

Project สำหรับเก็บ Patch และเครื่องมือจัดการเส้นทาง (Paths) และการกำหนดค่า Fleet สำหรับ `maw-js`.

## Tools

### 1. `patch_maw.sh`
สคริปต์สำหรับอัปเดตโค้ด `maw-js` ให้รองรับ:
- **Full Repo Slugs**: รวม domain (เช่น `github.com`) ในการสแกน fleet
- **Configurable Groups**: อนุญาตให้กำหนดลำดับและเซสชันผ่าน `maw.config.json`

#### การใช้งาน
```bash
chmod +x patch_maw.sh
./patch_maw.sh [path_to_maw_js]
```

## Configuration
หลังจากรัน patch แล้ว สามารถกำหนดค่าใน `maw.config.json` ได้ดังนี้:

```json
{
  "groups": {
    "gemi": { "session": "gemi", "order": 1 },
    "infographic": { "session": "infographic", "order": 2 }
  }
}
```

### 2. `maw.config.example.json`
ตัวอย่างไฟล์คอนฟิกสำหรับ `~/.config/maw/maw.config.json` ที่มีการเพิ่มส่วนของ `groups` เข้าไปแล้ว
