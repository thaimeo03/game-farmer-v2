# Farmer

Game 3D nông trại mạng xã hội phong cách low-poly, làm bằng **Godot 4.7** (GDScript).

- Trồng trọt, chăn nuôi, chế biến, giao đơn hàng, trang trí nhà riêng, thời trang & thú cưng, câu cá biển, đua thú, vòng quay, đu quay, ném vòng, cờ caro, đảo kho báu, đi xe buýt giữa các khu (Nông Trại, Bến Xe, Phố Chợ, Công Viên Vui Vẻ, Bãi Biển).
- Lưu game tự động, cây lớn khi offline, cấp độ mở khóa khu.

## Chạy

Mở thư mục này bằng Godot 4.7, nhấn F5 (scene chính: `scenes/main/main.tscn`).

| Phím | Tác dụng |
|---|---|
| WASD / mũi tên, Shift | Đi, chạy |
| E / Space / Click | Tương tác |
| 1–5 | Công cụ (bấm Hạt giống lần nữa để đổi hạt) |
| I / Tab | Túi đồ |
| B (trong nhà) | Trang trí: click đặt/cất đồ, R xoay |
| O | Tủ đồ: mặc phụ kiện, dắt thú cưng, chăm thú |
| J | Sổ tay cá |
| F1 | Admin (bản debug; tài khoản trong `config/admin.cfg`) |
| Chuột phải kéo, lăn chuột | Xoay, zoom camera |

## Test

```bash
godot --headless --path . tests/run_tests.tscn
```

## Cấu trúc & lộ trình

- `scripts/`, `scenes/`, `resources/` — chia theo tính năng (farm, zones, minigames, inventory, managers, ui).
- `assets/models/kenney/` — Kenney (CC0, giấy phép trong từng thư mục).
- `assets/models/props|crops/` — model dựng bằng Blender; file gốc ở `assets/models/source/farmer_props.blend`.
- Lộ trình & đặc tả: [docs/EXPANSION_PROMPT.md](docs/EXPANSION_PROMPT.md).
