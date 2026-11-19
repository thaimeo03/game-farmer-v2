# Prompt mở rộng — "Farmer": Thế giới nhiều khu + tính năng mạng xã hội nông trại

> Dán toàn bộ file này cho Claude Code (hoặc từng **Giai đoạn** một) để tiếp tục phát triển.
> Giai đoạn 1–3 đã xong. File này thay thế "Giai đoạn 4" cũ và mở rộng lộ trình tới GĐ 10.

---

## 0. Vai trò & nguyên tắc

Bạn là Senior Game Developer chuyên **Godot 4.7 (GDScript)**, game 3D stylized low-poly.
Tiếp tục phát triển dự án `farmer-godot` theo từng giai đoạn; **xong một giai đoạn thì dừng để tôi xác nhận**.

**Nguyên tắc bắt buộc**
- **Cảm hứng, không sao chép:** lấy *cảm giác* và *cơ chế* của các game mạng xã hội nông trại kiểu Avatar (ấm cúng, cộng đồng, thời trang, cày xu ở khu giải trí). **Tên khu, nhân vật, hình ảnh, âm thanh, logo phải là của riêng game này**; không dùng tài sản hay thương hiệu của game khác.
- **Tái sử dụng kiến trúc sẵn có** (mục 1) thay vì viết lại. Ưu tiên dữ liệu bằng `Resource` (`.tres`) để thêm nội dung không cần sửa code.
- Mỗi tính năng mới có **test trong `tests/run_tests.tscn`**, và mỗi giai đoạn **ghi hình kiểm tra** (`--write-movie`) rồi gửi ảnh chụp.
- Model: dùng **Kenney CC0** sẵn có trong `assets/models/kenney/`; thứ gì Kenney không có thì **dựng bằng Blender qua MCP** (helper `fp_helpers` trong `assets/models/source/farmer_props.blend`, xuất `.glb` vào `assets/models/props/`). Model mới phải đứng đúng gốc tọa độ (min z = 0).
- Không có tiền thật. "Lượng" (tiền cao cấp) chỉ kiếm trong game (nhiệm vụ, sự kiện, thành tích). Vòng quay/cược chỉ dùng xu trong game và có giới hạn mỗi ngày.
- UI và chữ trong game bằng **tiếng Việt**.

---

## 1. Hiện trạng (đã có — dùng lại)

| Hệ thống | File chính | Ghi chú |
|---|---|---|
| Nhân vật, camera | `scripts/player/player.gd`, `camera_rig.gd` | Kenney Mini Character, `begin_activity()/end_activity()`, cầm dụng cụ qua `BoneAttachment3D` |
| Nông trại | `scripts/farm/farm_grid.gd`, `farm_plot.gd`, `crop_data.gd` | Cây lớn theo `GameState.clock`, hàng rào tự dựng |
| Kho đồ, kinh tế | `scripts/inventory/*.gd`, `scripts/managers/game_state.gd` | `ItemData` (có `model`), `Inventory`, `buy/sell/spend/earn` |
| HUD | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Quickbar, túi đồ, shop, bảng cược, thanh canh thời điểm, toast, fade |
| Chuyển khu | `scripts/managers/main.gd`, `portal.gd` | Main giữ Player + HUD, **cache khu** khi rời đi |
| Tương tác | `scripts/utils/interact_zone.gd` | Đứng gần → hiện `[E] ...` → `interact()` |
| Thế giới | `scripts/utils/terrain.gd`, `scatter.gd` | Đồi low-poly, ao, đường đất, rải cây/hoa theo địa hình |
| Mini-game | `scripts/minigames/fishing_spot.gd`, `pet_race.gd` | Câu cá có độ hiếm, đua thú có cược |

---

## 2. Bản đồ thế giới mới — các khu riêng nối bằng xe buýt

Mỗi khu là **một scene riêng** trong `scenes/zones/`, có **trạm xe buýt** của khu đó. Từ trạm, người chơi mở **Bảng tuyến xe** để chọn điểm đến.

| Khu | Scene | Nội dung chính | Mở khóa |
|---|---|---|---|
| **Nông Trại Của Tôi** | `zones/my_farm.tscn` | Ruộng mở rộng theo cấp, chuồng thú, ao cá nhà, **nhà riêng** (vào trong), máy chế biến, hộp thư | Từ đầu |
| **Bến Xe Trung Tâm** | `zones/bus_terminal.tscn` | Bến lớn nhiều làn xe, bảng giờ, NPC bán vé, ghế chờ, máy bán nước | Từ đầu |
| **Phố Chợ** (thành phố 1) | `zones/market_town.tscn` | Chợ nông sản, shop hạt giống/nông cụ, shop thú cưng, bảng nhiệm vụ, bưu điện (gửi quà) | Từ đầu |
| **Đại Lộ Thời Trang** (thành phố 2) | `zones/fashion_avenue.tscn` | Shop thời trang (thử đồ có xem trước 3D), shop nội thất, tiệm tóc, quảng trường sự kiện, sân khấu nhảy | Cấp 3 |
| **Công Viên Vui Vẻ** (khu giải trí) | `zones/fun_park.tscn` | Đua thú (dời từ City), vòng quay may mắn, đu quay ngồi được, ném vòng, bàn đá cờ caro | Cấp 2 |
| **Bãi Biển Nắng Vàng** (khu du lịch) | `zones/sunny_beach.tscn` | Câu cá biển (bảng cá khác), nhặt vỏ sò, thuyền ra đảo, chụp ảnh check-in, quầy dừa | Cấp 3 |
| **Đảo Nhỏ** (tùy chọn) | `zones/little_isle.tscn` | Hải đăng, rương kho báu hằng ngày, cá hiếm (đi thuyền từ Bãi Biển) | Cấp 4 |

**Cơ chế xe buýt**
- `ZoneData` (Resource): `id`, `display_name`, `scene_path`, `bus_stop_marker`, `unlock_level`, `ticket_price`, `icon`, `music`.
- Trạm xe = `InteractZone` + model xe buýt và mái chờ. Bấm E → **Bảng tuyến** (UI dạng bản đồ hoặc danh sách) hiện các khu: khu khóa thì xám và ghi "Cần cấp X", vé hiển thị bằng xu.
- Chọn điểm đến → **cảnh xe chạy**: xe buýt lăn bánh rời bến, màn tối dần, hiện thẻ tên khu ("Đang đến Bãi Biển Nắng Vàng..."), rồi tới khu mới với xe đang đỗ ở trạm và người chơi bước xuống. Dùng lại `Main.travel()`.
- Cổng dịch chuyển hiện tại được thay bằng trạm xe; có thể giữ cổng làm lối tắt giữa nông trại và bến xe.
- Mỗi khu có **nhạc nền và ánh sáng riêng** (`WorldEnvironment` + `AudioStreamPlayer`), và có điểm hồi sinh `Marker3D` tên `BusStop`.

---

## 3. Tính năng mở rộng (kiểu game mạng xã hội nông trại)

### 3.1 Cấp độ & tiến trình
- `ProgressionManager` (autoload): EXP, cấp, bảng EXP theo cấp. Mọi hành động có EXP: trồng, thu hoạch, câu cá, cho thú ăn, hoàn thành nhiệm vụ...
- Lên cấp: hiệu ứng pháo giấy, toast, **mở khóa** (ô đất, khu, vật phẩm trong shop, công thức chế biến).
- Bảng **thành tích** (thu 100 cà rốt, câu 10 cá vàng...) thưởng Lượng.

### 3.2 Lưu game
- `SaveManager` (autoload): JSON trong `user://saves/slot_N.json`; tự lưu mỗi 60 giây và khi đổi khu.
- Lưu: ví, túi đồ (theo `ItemData.id` → tra bảng `ItemDatabase`), cấp/EXP, trạng thái từng ô đất, thú nuôi, nội thất, trang phục, nhiệm vụ, thời gian thực.
- **Lớn khi offline:** cây và thú dùng mốc thời gian Unix, nên mở game lại thì thấy cây đã lớn.

### 3.3 Nông trại nâng cao
- **Mở rộng đất:** mua thêm ô theo cấp (lưới lớn dần), giá tăng dần.
- **Chăm sóc cây:** cây khô nếu quá lâu không tưới (cần tưới lại mỗi giai đoạn); **sâu bệnh/cỏ dại** xuất hiện ngẫu nhiên, xử lý bằng thuốc hoặc nhổ tay; **phân bón** rút ngắn thời gian; cây mùa nào trồng mùa nấy (tùy chọn).
- **Chuồng thú:** gà (trứng), bò (sữa), heo (nấm truffle), cừu (len). `AnimalData`: thức ăn, thời gian ra sản phẩm, giá. Thú đi lang thang trong chuồng; đói thì hiện biểu tượng. Dùng Kenney Cube Pets.
- **Ao cá nhà:** thả cá giống, lớn theo thời gian, vớt bằng vợt.
- **Chế biến:** lò bánh, máy ép nước, nồi nấu, khung dệt. `RecipeData`: nguyên liệu → thành phẩm, thời gian, cấp mở khóa. Có hàng đợi sản xuất.
- **Đơn hàng giao xe tải:** bảng 3 đơn ngẫu nhiên ("5 trứng + 3 bánh mì"), thưởng xu + EXP, làm mới theo thời gian.

### 3.4 Nhà riêng & nội thất
- Bước vào cửa nhà ở nông trại → scene nội thất (`zones/my_house.tscn`).
- **Chế độ trang trí:** lưới đặt đồ, xoay 90°, cất về kho, không cho chồng chéo. `FurnitureData`: kích thước ô, giá, model, có ngồi/nằm được không.
- Ghế/giường **ngồi hoặc nằm được** (animation `sit`). Hình nền tường, sàn đổi được.
- Điểm "Đẹp nhà" tính từ đồ đạc, mở thành tích.

### 3.5 Thời trang & ngoại hình
- **Chọn nhân vật cơ sở** (các Kenney Mini Character), đổi màu da/tóc qua shader tint, hoặc qua bảng màu của texture `colormap`.
- **Phụ kiện gắn xương** (`BoneAttachment3D` vào `head`/`torso`): mũ, kính, khăn, balo, cánh, hào quang. Model dựng bằng Blender. `OutfitData`: slot, model, giá xu/lượng, cấp.
- **Shop thời trang có phòng thử đồ:** khung xem trước 3D (SubViewport) xoay được, thử trước rồi mới mua.
- **Tủ đồ:** lưu bộ trang phục và đổi nhanh.

### 3.6 Thú cưng
- Mua ở shop thú cưng (Kenney Cube Pets). Pet **đi theo chủ** (nav/steering), ngồi khi chủ đứng yên, có tên và độ thân thiết.
- Cho ăn và chơi để tăng chỉ số; pet có **tốc độ/sức bền** để **đem đi đua** ở Công Viên Vui Vẻ (cùng với thú của NPC).

### 3.7 Khu vui chơi & mini-game
- **Vòng quay may mắn:** quay bằng vé hoặc xu, phần thưởng có trọng số (hạt hiếm, đồ trang trí, trang phục, Lượng), giới hạn lượt mỗi ngày.
- **Đu quay khổng lồ:** ngồi vào cabin, camera quay toàn cảnh khu.
- **Ném vòng:** canh lực và góc ném, trúng chai thì có điểm.
- **Cờ caro** (bàn đá ở công viên): UI 2D overlay, bàn 15×15, đối thủ AI 3 mức, thắng nhận xu.
- **Câu cá biển:** bảng cá riêng của bãi biển; **Sổ tay cá** ghi loại đã câu và kích thước lớn nhất.
- **Nhặt vỏ sò**: vỏ xuất hiện ngẫu nhiên trên cát, bán hoặc đổi quà.

### 3.8 Xã hội (giả lập trước, online sau)
- **Hàng xóm NPC:** 6–8 NPC có tên, ngoại hình, lịch sinh hoạt theo giờ trong game; đi lại giữa các khu (dùng `NavigationAgent3D`).
- **Trò chuyện:** bong bóng hội thoại, cây hội thoại đơn giản (`DialogueData`), **điểm thân thiết** tăng khi tặng quà hoặc nói chuyện; mức thân thiết cao mở nhiệm vụ riêng.
- **Thăm nông trại:** NPC ghé nông trại, có khi giúp tưới cây hoặc để lại quà trong hộp thư.
- **Biểu cảm (emote):** vòng chọn emote (vẫy tay, nhảy, cười, buồn, ngồi) dùng animation sẵn có của Kenney; NPC phản hồi emote.
- **Bưu điện:** gửi quà cho NPC, nhận thư và quà sự kiện.

### 3.9 Nhiệm vụ & sự kiện
- `QuestManager` (autoload) + `QuestData`: nhiệm vụ tân thủ (hướng dẫn từng bước), nhiệm vụ hằng ngày (3 việc/ngày), nhiệm vụ của NPC. Có **sổ nhiệm vụ** trong HUD, và mũi tên chỉ đường tới mục tiêu.
- **Ngày–đêm** theo `GameState.clock` (đổi màu mặt trời và bầu trời, đèn đường bật ban đêm); **thời tiết**: mưa tự tưới cây, cầu vồng sau mưa.
- **Sự kiện mùa** (ví dụ Lễ hội Trăng Rằm, Tết): trang trí khu, vật phẩm và nhiệm vụ giới hạn thời gian, thiết kế bằng `EventData` để bật/tắt theo ngày.

### 3.10 UI / UX
- HUD thêm: thanh EXP/cấp, nút bản đồ, sổ nhiệm vụ, hồ sơ nhân vật, tủ đồ, vòng emote.
- Túi đồ chia tab (Hạt giống / Nông sản / Cá / Đồ chế biến / Trang phục / Nội thất), có sắp xếp.
- Bộ **icon thật** cho vật phẩm (render từ model bằng SubViewport ra PNG, hoặc dùng Kenney icons).
- Cài đặt: âm lượng, độ phân giải bóng, độ nhạy chuột, phím tắt.
- **Điều khiển cảm ứng** (joystick ảo, nút tương tác) để sẵn sàng xuất Android.

### 3.11 Âm thanh
- Nhạc nền riêng từng khu, hiệu ứng (cuốc đất, tưới, thu hoạch, câu cá, xu, lên cấp). Nguồn CC0 (Kenney Audio, freesound CC0); ghi giấy phép vào `assets/audio/LICENSES.md`.

---

## 4. Lộ trình triển khai

Mỗi giai đoạn kết thúc bằng: test xanh, ảnh chụp từ ghi hình, tóm tắt thay đổi, và dừng chờ xác nhận.

| GĐ | Tên | Phạm vi | Tiêu chí hoàn thành |
|---|---|---|---|
| **4** ✅ | **Nền móng thế giới** | `ZoneData`; tách khu: Nông Trại Của Tôi, Bến Xe, Phố Chợ, Công Viên Vui Vẻ (dời đua thú), Bãi Biển (dời câu cá); **xe buýt + Bảng tuyến + cảnh xe chạy**; `SaveManager` + `ItemDatabase`; `ProgressionManager` (EXP, cấp, mở khóa khu) | Đi xe buýt tới cả 5 khu; khu khóa theo cấp; thoát game rồi mở lại vẫn giữ ví, túi, ruộng, cấp; cây lớn khi offline |
| **5** ✅ | **Nông trại nâng cao** | Mở rộng đất, khô/sâu/cỏ/phân bón, chuồng gà/bò/heo/cừu, ao cá nhà, 4 máy chế biến, đơn hàng xe tải | Vòng chơi trồng → chế biến → giao đơn chạy trọn; có test cho công thức và cho thú |
| **6** ✅ | **Nhà riêng** | Scene trong nhà, chế độ trang trí theo lưới, 20+ món nội thất (Kenney Furniture Kit + Blender), ngồi/nằm | Đặt, xoay, cất đồ; lưu và tải bố cục đúng |
| **7** ✅ | **Thời trang & Pet** | Nhân vật cơ sở, đổi màu, phụ kiện gắn xương, shop có phòng thử, tủ đồ; pet theo chủ, chăm sóc, đem đi đua | Thử, mua, mặc, lưu trang phục; pet theo chủ qua mọi khu |
| **8** ✅ | **Giải trí & du lịch** | Vòng quay, đu quay, ném vòng, cờ caro AI, câu cá biển + sổ tay cá, nhặt vỏ sò, thuyền ra đảo | Mỗi mini-game có thưởng và giới hạn ngày; AI caro không đi nước sai luật |
| **9** ✅ | **Xã hội & sự kiện** | NPC hàng xóm có lịch, hội thoại, thân thiết, quà, emote, bưu điện; nhiệm vụ tân thủ/hằng ngày; ngày–đêm, thời tiết; 1 sự kiện mùa mẫu | Người mới được hướng dẫn trọn vòng; NPC đi đúng lịch; mưa tự tưới cây |
| **10** | **Hoàn thiện & online** | Âm thanh, cài đặt, icon thật, tối ưu (MultiMesh cho cỏ/hoa, LOD, gom draw call), điều khiển cảm ứng; **(tùy chọn) multiplayer**: Godot high-level multiplayer + server, thấy người chơi khác ở cùng khu, chat, thăm nông trại bạn bè | 60 FPS trên máy tầm trung; xuất được bản Windows/Android; (online) 2 client gặp nhau cùng khu |

---

## 5. Ràng buộc kỹ thuật

- **Autoload:** giữ `GameState` (ví, túi, đồng hồ, event bus). Thêm `SaveManager`, `ProgressionManager`, `QuestManager`, `ItemDatabase` — mỗi cái một việc, giao tiếp qua signal.
- **Dữ liệu:** `ZoneData`, `AnimalData`, `RecipeData`, `FurnitureData`, `OutfitData`, `QuestData`, `DialogueData`, `EventData` đặt trong `scripts/<feature>/`; file `.tres` để trong `resources/<loại>/`. Mọi Resource có `id: StringName` duy nhất để lưu game.
- **Khu:** mỗi khu gồm `Terrain` + `Scatter` + `WorldEnvironment` (dùng chung `resources/world_environment.tres`, hoặc biến thể riêng của khu), có `Marker3D` tên `BusStop`. `Main` vẫn cache khu đã vào.
- **Tương tác:** mọi NPC, máy, đồ vật dùng `InteractZone`; UI modal dùng cơ chế `_open_modal()/close_panels()` của HUD, và `GameState.ui_busy` để khóa input.
- **Test:** `tests/run_tests.tscn` (chạy dạng scene vì autoload). Mỗi hệ thống dữ liệu (công thức, EXP, lưu/tải, đơn hàng, AI caro) phải có test.
- **Asset:** Kenney trước, Blender sau. Đặt tên rõ ràng, tôn trọng `.gdignore` ở thư mục `source/`. Nếu tải gói Kenney Nature Kit mới thì phải vá vật liệu (metallic = 0, màu sRGB → linear) như đã làm.
- **Hiệu năng:** cỏ và hoa nhiều thì chuyển `Scatter` sang `MultiMeshInstance3D`; khu không ở trong cây scene thì không chạy `_process`, trừ các thứ tính theo đồng hồ.

---

## 6. Đầu ra mong muốn mỗi giai đoạn

1. Danh sách file mới và file đã sửa, kèm một dòng mô tả mỗi file.
2. Cây scene của các scene mới (dạng thụt dòng).
3. Kết quả test và 3–5 ảnh chụp từ ghi hình.
4. Những gì chưa làm hoặc chưa kiểm chứng, và rủi ro cần biết.
5. Dừng lại, hỏi tôi trước khi sang giai đoạn tiếp theo.

**Bắt đầu với Giai đoạn 4.**
