# ⚡ Wattman - Real-time Charging Wattage & Battery Monitor

**Wattman** là ứng dụng iOS nhỏ gọn, hiện đại chuyên dùng để **đo công suất sạc thời gian thực (Watts)** và theo dõi trọn bộ thông số phần cứng của pin dành cho các thiết bị cài đặt qua **TrollStore** (hoặc máy đã Jailbreak).

Ứng dụng kế thừa công nghệ đọc phần cứng cấp thấp (`AppleSMC` và `Texas Instruments Gas Gauge IC`) từ dự án [Torrekie/Battman](https://github.com/Torrekie/Battman), nhưng được tinh gọn lại 100% để tập trung vào trải nghiệm đo công suất nhanh, nhẹ, giao diện trực quan và không can thiệp sâu làm ảnh hưởng đến hệ thống.

---

## 📸 Tính năng nổi bật

* ⚡ **Đo công suất sạc tức thời (Watts)**:
  * Tính toán trực tiếp theo công thức $P = U \times I$ từ thanh ghi phần cứng chip đo pin.
  * Hiển thị số Watt to, nổi bật kèm đổi màu thông minh:
    * 🟢 **Màu xanh lá**: Đang nhận sạc (kèm nhãn nhận diện Sạc nhanh USB-PD).
    * 🟠 **Màu cam/đỏ**: Đang xả pin ở mức công suất cao (chơi game, quay video).
    * 🔵 **Màu xanh dương**: Đang xả pin ở mức bình thường.
  * Cập nhật chỉ số điện áp ($mV$) và dòng điện nạp/xả ($mA$) theo thời gian thực mỗi giây.
* 🔋 **Thông số & Sức khỏe pin chuyên sâu**:
  * **Sức khỏe pin (Battery Health)**: Tỷ lệ $\%$ dung lượng thực tế so với dung lượng thiết kế ban đầu.
  * **Mức pin thực tế (SoC)**: Đọc trực tiếp từ chip đo pin (chính xác hơn % hiển thị trên thanh trạng thái).
  * **Dung lượng thực tế vs Thiết kế**: Hiển thị chính xác dung lượng pin còn lại, dung lượng sạc đầy (FCC) và dung lượng thiết kế chuẩn theo đơn vị $mAh$.
  * **Số chu kỳ sạc (Cycle Count)**: Đếm số lần sạc xả trọn vẹn từ chip đo pin.
  * **Nhiệt độ cell pin**: Đo đạc nhiệt độ trực tiếp từ cảm biến nhiệt tích hợp trong cell pin ($^\circ\text{C}$).
* 🔌 **Nhận diện nguồn sạc & Năng lượng**:
  * Tự động phát hiện khi cắm sạc hoặc rút sạc.
  * Ước tính thời gian sử dụng pin còn lại.

---

## 📲 Hướng dẫn cài đặt qua TrollStore

Vì ứng dụng cần các quyền đặc quyền cấp hệ thống (**Private Entitlements**) để đọc thanh ghi của chip `AppleSMC`, bạn cần cài đặt thông qua **TrollStore**:

1. Tải về file **`Wattman.tipa`** (hoặc **`Wattman.ipa`**) từ mục **[Releases](../../releases)** hoặc từ Artifacts của **GitHub Actions**.
2. Chia sẻ / Mở file vừa tải về bằng ứng dụng **TrollStore**.
3. Chọn **Install** để cài đặt. Ứng dụng sẽ hoạt động vĩnh viễn mà không bao giờ bị thu hồi chứng chỉ hay giới hạn 7 ngày!

---

## 🛠️ Tự động Build bằng GitHub Actions (Không cần Mac)

Repository này đã được tích hợp sẵn kịch bản **GitHub Actions CI/CD** (`.github/workflows/build.yml`):

1. **Fork** hoặc **Push** repo này lên tài khoản GitHub của bạn.
2. Vào tab **Actions** trên GitHub, chọn workflow **Build Wattman (TrollStore IPA/TIPA)** và bấm **Run workflow**.
3. Sau khoảng 2–3 phút, máy ảo Ubuntu sẽ tự động biên dịch và xuất ra file `Wattman.tipa` / `Wattman.ipa` trong mục Artifacts để bạn tải về máy!

---

## 💻 Tự biên dịch thủ công (Local Build)

### 1. Trên Linux / Theos:
Cần chuẩn bị LLVM cross-toolchain iOS và `iPhoneOS13.7.sdk`:
```bash
make -C Wattman all
# File đầu ra sẽ nằm tại Wattman/build/Wattman.tipa
```

### 2. Trên macOS (với Xcode):
```bash
make -C Wattman CC="xcrun -sdk iphoneos clang" all
```

---

## ⚖️ Bản quyền & Ghi công (Attribution)

* Dự án được xây dựng dựa trên công nghệ đọc chip `AppleSMC` từ [Torrekie/Battman](https://github.com/Torrekie/Battman) theo giấy phép phi thương mại *Torrekie Non-Commercial Attribution License v1.0*.
* Tác giả tái cấu trúc & phát triển Mini-App: [tuaniuminh](https://github.com/tuaniuminh).
