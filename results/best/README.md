# Snapshot tốt nhất: 20261110_162941_128

Phiên MATLAB được lưu lúc **16:29:47 ngày 10/11/2026 (UTC+7)**. Chọn theo PSNR cao nhất trong ba kết quả đã so sánh: **16,716386594 dB**, MAE **23,571152519**, preamble score **0,88**.

- `results/recovered_image.png`: ảnh hiển thị ở Figure 3, đã kiểm tra khớp `DemA` trong workspace.
- `results/decoding_workspace.mat`: workspace giải mã gốc.
- `recording/NUS_AOFDM_RX_debug.mat`: mẫu microphone và thông số đồng bộ.
- `config/session_TX_parameters.mat`: tham số lấy từ chính phiên giải mã; ưu tiên file này khi xử lý lại bản ghi.
- Các file khác trong `config/`: bộ phát và ảnh trên đĩa khi lưu phiên. Các trường tham số TX đã được đối chiếu và khớp với tham số phiên.
- `figures/`: hình chẩn đoán/ảnh thu/hướng dẫn đã lưu. File `.fig` được giữ cục bộ và Git bỏ qua; bản PNG được đưa lên repo.
- `code/`: nguyên bản mã tại thời điểm lưu, chưa áp dụng cấu trúc đường dẫn mới. Chạy mã hiện tại trong `../../matlab/` theo README gốc.
- `manifest.json`: metadata gốc của phiên.
- `selection.json`: tiêu chí chọn và đường dẫn để đối chiếu.

Ảnh vẫn còn nhiễu. Đây là kết quả tốt nhất trong các mẫu hiện có, không phải xác nhận truyền ảnh không lỗi. Không có Figure 2 trong snapshot gốc.
