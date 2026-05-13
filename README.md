# Path Oracle 🌊

Project สำหรับเก็บ Patch และเครื่องมือจัดการเส้นทาง (Paths) และการกำหนดค่า Fleet สำหรับ `maw-js`.

## Tools

### 1. `patch_maw.sh`
- **Safe-Reset & Version Check**: ตรวจสอบเวอร์ชัน `package.json` และล้างสถานะไฟล์เป้าหมายด้วย `git checkout` ก่อนเริ่ม Patch เพื่อความแม่นยำสูงสุด
สคริปต์สำหรับอัปเดตโค้ด `maw-js` ให้รองรับ:
- **Full Repo Slugs**: รวม domain (เช่น `github.com`) ในการสแกน fleet
- **Configurable Groups**: อนุญาตให้กำหนดลำดับและเซสชันผ่าน `maw.config.json`
- **Auto-resize Tmux (Latest)**: แก้ไขปัญหา "จุดไข่ปลา `...`" ด้านข้างหน้าจอ (โดยเฉพาะเมื่อต่อ Projector) โดยการตั้งค่า `window-size latest` อัตโนมัติ
- **CLI Wake All Support**: แทรก logic `maw wake all` เข้าไปในระบบอัตโนมัติ (แม้จะเป็นเวอร์ชันใหม่จาก GitHub)
- **Version Integrity**: เพิ่มเครื่องหมาย `(patched 🌊)` ใน `maw --version` เพื่อความโปร่งใส

#### การติดตั้งและอัปเดต (Installation & Update)
```bash
chmod +x patch_maw.sh
./patch_maw.sh [path_to_maw_js]
```

> **Note**: เมื่อรันสคริปต์เสร็จ ระบบจะทำการ `bun run build` ให้โดยอัตโนมัติเพื่อให้โค้ดใหม่มีผลทันที

#### การตรวจสอบเวอร์ชัน (Verification)
หลังจากการ Patch สำเร็จ เมื่อรันคำสั่งต่อไปนี้:
```bash
maw --version
```
ควรจะแสดงผลลัพธ์ที่มีคำว่า **`(patched 🌊)`** เช่น:
`maw v(patched 🌊) 26.5.2 (020e5ff5) built 2026-05-04 Mon 16:35`

#### การทำให้การเปลี่ยนแปลงมีผล (Restart)
เพื่อให้การตั้งค่าหน้าจอแบบใหม่ (Latest) ทำงานกับเซสชันเดิมที่เปิดค้างไว้:
1. ปิดเซสชันเดิม: `maw kill <session_name>` หรือ `maw kill --all`
2. เริ่มเซสชันใหม่: `maw wake <oracle_name>` หรือ `maw wake all`

---

### 2. `maw.config.example.json`
ตัวอย่างไฟล์คอนฟิกสำหรับ `~/.config/maw/maw.config.json` ที่มีการเพิ่มส่วนของ `groups` เข้าไปแล้ว

---

## คู่มือการตั้งค่า Fleet (The Golden Sequence) 🛠️

เมื่อทำการ Patch ระบบเรียบร้อยแล้ว ให้ทำตามลำดับขั้นตอนดังนี้เพื่อให้ Fleet ทำงานได้อย่างถูกต้อง:

### 1. ค้นหา Oracle Repos
```bash
maw oracle scan
```
*   **หน้าที่**: สแกนหาโปรเจกต์ Oracle ในเครื่องและสร้าง `oracles.json`

### 2. สร้างไฟล์คอนฟิก Fleet
```bash
maw fleet init
```
*   **หน้าที่**: ลบไฟล์เก่าใน `~/.config/maw/fleet/` และสร้างไฟล์ใหม่โดยอิงจาก `groups` ใน `maw.config.json`
*   **ผลลัพธ์**: จะได้ไฟล์เลขลำดับ เช่น `01-pulse.json`, `02-hermes.json`

### 3. จัดระเบียบเลข (ทางเลือก)
```bash
maw fleet renumber
```
*   **หน้าที่**: ตรวจสอบและเรียงลำดับเลขหน้าไฟล์ `.json` ให้สวยงาม (01, 02, 03...) กรณีที่มีการเพิ่มไฟล์ด้วยมือหรือเลขซ้ำ

### 4. ปลุก Oracle ทั้งหมด
```bash
maw wake all
```
*   **หน้าที่**: เริ่มการทำงานของ Oracle ทุกตัวตามคอนฟิก และบันทึกสถานะลงใน `maw.config.json`

---

## กรณีที่มีการสร้าง Oracle ใหม่ 🌊

หากมีการเพิ่ม Oracle Repo ใหม่ในเครื่อง ให้รันขั้นตอนดังนี้:

1.  **สแกนใหม่**: รัน `maw oracle scan` เพื่อให้ระบบรู้จัก Repo ใหม่
2.  **อัปเดต Config**: เพิ่มชื่อ Oracle ใหม่ลงใน `groups` ของ `maw.config.json` หากต้องการระบุลำดับ (Order) ที่แน่นอน
3.  **สร้าง Fleet ใหม่**: รัน `maw fleet init` เพื่อสร้างไฟล์ `.json` สำหรับ Oracle ใหม่
4.  **ปลุกระบบ**: รัน `maw wake all` หรือ `maw wake [ชื่อ-oracle]` เพื่อเริ่มใช้งาน

---
**หมายเหตุ**: การรัน `maw fleet init` จะลบไฟล์ในโฟลเดอร์ `fleet/` เดิมทิ้งเสมอ เพื่อป้องกันความสับสนของลำดับเลข
