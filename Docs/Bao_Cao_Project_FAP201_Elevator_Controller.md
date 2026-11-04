# TRƯỜNG ĐẠI HỌC FPT - FPT UNIVERSITY
## BỘ MÔN KỸ THUẬT PHẦN CỨNG & THIẾT KẾ VI MẠCH (FAP201)

---

# BÁO CÁO ĐỒ ÁN MÔN HỌC FAP201
### ĐỀ TÀI:
## THIẾT KẾ VÀ KIỂM CHỨNG BỘ ĐIỀU KHIỂN THANG MÁY ĐA TẦNG (ELEVATOR CONTROLLER) BẰNG VERILOG TRÊN FPGA GOWIN GW5A

* **Mã môn học:** FAP201
* **Tên môn học:** IC Design & FPGA Programming
* **Kỳ học:** Semester 4
* **Đề tài:** Elevator Controller
* **Công cụ thiết kế & mô phỏng:** Verilog HDL, Python 3, ModelSim Intel FPGA Edition, Gowin EDA

---

## MỤC LỤC
1. [CHƯƠNG 1: TỔNG QUAN ĐỀ TÀI & YÊU CẦU KỸ THUẬT](#chương-1-tổng-quan-đề-tài--yêu-cầu-kỹ-thuật)
2. [CHƯƠNG 2: MÔ HÌNH THAM CHIẾU (GOLDEN MODEL) & SINH TESTCASE BẰNG PYTHON](#chương-2-mô-hình-tham-chiếu-golden-model--sinh-testcase-bằng-python)
3. [CHƯƠNG 3: THIẾT KẾ PHẦN CỨNG RTL THEO PHƯƠNG PHÁP TOP-DOWN](#chương-3-thiết-kế-phần-cứng-rtl-theo-phương-pháp-top-down)
4. [CHƯƠNG 4: MÔ PHỎNG & ĐỐI SOÁT TƯƠNG ĐƯƠNG (VERIFICATION)](#chương-4-mô-phỏng--đối-soát-tương-đương-verification)
5. [CHƯƠNG 5: HIỆN THỰC HÓA VÀ ÁNH XẠ CHÂN TRÊN KIT FPGA GOWIN](#chương-5-hiện-thực-hóa-và-ánh-xạ-chân-trên-kit-fpga-gowin)
6. [CHƯƠNG 6: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN](#chương-6-kết-luận-và-hướng-phát-triển)

---

## CHƯƠNG 1: TỔNG QUAN ĐỀ TÀI & YÊU CẦU KỸ THUẬT

### 1.1. Đặt vấn đề
Hệ thống thang máy là một hệ thống nhúng thời gian thực (real-time embedded system) điển hình, đòi hỏi độ tin cậy, an toàn và tính đáp ứng cao. Trong thiết kế vi mạch (IC Design) và lập trình FPGA, việc hiện thực hóa bộ điều khiển thang máy (Elevator Controller) là bài toán kinh điển để rèn luyện tư duy thiết kế phần cứng theo cấu trúc phân cấp (Top-Down), xây dựng máy trạng thái hữu hạn (FSM), xử lý tín hiệu ngoại vi và quy trình kiểm thử đối soát tự động (Golden Model Verification).

### 1.2. Yêu cầu kỹ thuật theo đề cương FAP201
Theo quy định đồ án môn học:
1. **Phương pháp sinh Testcase:** Sử dụng **Python** để xây dựng bộ sinh testcase tự động, bao quát từ các kịch bản định hướng (Directed Tests) đến các ca kiểm thử áp lực ngẫu nhiên (Random Stress Tests).
2. **Golden Model:** Xây dựng mô hình tham chiếu bằng ngôn ngữ bậc cao (Python) phản ánh cycle-accurate hành vi dự kiến của hệ thống để làm thước đo đánh giá RTL.
3. **Thiết kế RTL:**
   * Áp dụng phương pháp phân cấp **Top-Down**, chia nhỏ hệ thống thành các module chức năng độc lập, ghép nối qua module đỉnh (`elevator_top`).
   * Sử dụng Verilog HDL tuân thủ chuẩn tổng hợp phần cứng (Synthesis-friendly).
4. **Testbench & Đối soát:**
   * Viết Testbench tự động đọc stimulus từ file, áp tín hiệu vào RTL và xuất file kết quả mô phỏng.
   * Xây dựng script đối soát tự động báo cáo Pass/Fail chính xác từng xung clock (100% Match).
5. **Đẩy lên GitHub:** Tổ chức cấu trúc mã nguồn gồm thư mục `rtl/`, `testbench/`, `golden_model/`, `sim/`, và file `README.md` theo chuẩn quốc tế.

### 1.3. Thuật toán lập lịch LOOK / SCAN
Thay vì di chuyển ngẫu nhiên hay chỉ phục vụ theo thứ tự thời gian bấm (FIFO), hệ thống ứng dụng thuật toán **LOOK (Elevator Algorithm)**:
* Khi thang máy đang di chuyển theo một hướng (ví dụ: Đang đi LÊN), hệ thống sẽ tiếp tục di chuyển và phục vụ lần lượt tất cả các yêu cầu gọi tầng ở phía trên theo chiều tăng dần.
* Khi đã phục vụ hết tất cả các tầng ở phía trên:
  * Nếu có yêu cầu ở các tầng phía dưới -> Đổi hướng sang đi XUỐNG.
  * Nếu không còn yêu cầu nào trong tòa nhà -> Chuyển về trạng thái chờ (`IDLE`).
* Thuật toán này giúp tối ưu hóa quãng đường di chuyển của cabin, tiết kiệm năng lượng động cơ và giảm thời gian chờ đợi trung bình của hành khách.

### 1.4. Yêu cầu an toàn
* **Cảm biến chống kẹt cửa (Anti-Pinch Door Sensor):** Khi cửa đang đóng (`DOOR_CLOSING`), nếu phát hiện có người hoặc vật cản chướng ngại (`door_sensor = 1`), cửa thang máy phải ngay lập tức hủy lệnh đóng và mở lại hoàn toàn (`DOOR_OPEN`).
* **Nút dừng khẩn cấp (Emergency Stop):** Khi nút khẩn cấp được kích hoạt (`emergency_btn = 1`), thang máy dừng ngay lập tức, mở cửa thoát hiểm, ngắt các lệnh di chuyển và xóa danh sách hàng đợi đang chờ để phục vụ công tác cứu hộ.

---

## CHƯƠNG 2: MÔ HÌNH THAM CHIẾU (GOLDEN MODEL) & SINH TESTCASE BẰNG PYTHON

### 2.1. Khái niệm và vai trò của Golden Model
Trong quy trình thiết kế vi mạch công nghiệp (ASIC/FPGA Design Flow), trước khi bắt tay vào viết RTL, kỹ sư thiết kế và kỹ sư kiểm thử (DV Engineer) phải xây dựng một mô hình tham chiếu gọi là **Golden Model**. Golden Model được viết bằng ngôn ngữ phần mềm bậc cao (như Python hoặc C++) để:
* Xác minh tính đúng đắn của giải thuật trước khi hiện thực hóa trên phần cứng.
* Cung cấp tập dữ liệu mẫu kỳ vọng (Golden Expected Output) hoàn toàn khách quan để đối chứng với kết quả mô phỏng phần cứng RTL.

### 2.2. Hiện thực hóa Golden Model (`elevator_golden_model.py`)
Mô hình `ElevatorGoldenModel` được thiết kế tương thích chu kỳ (cycle-accurate) với các thông số:
* Số tầng: 4 tầng (Tầng 1 đến Tầng 4, mã hóa nhị phân `0..3`).
* 6 trạng thái FSM: `IDLE (0)`, `MOVING_UP (1)`, `MOVING_DOWN (2)`, `DOOR_OPEN (3)`, `DOOR_CLOSING (4)`, `EMERGENCY (5)`.
* Tham số thời gian: `MOVE_TICKS = 10` chu kỳ/tầng, `DOOR_OPEN_TICKS = 10` chu kỳ, `DOOR_CLOSE_TICKS = 4` chu kỳ.
* Hàm `step(req_btn, door_sensor, emergency_btn, rst_n)` cập nhật thanh ghi và trạng thái tương tự như một chu kỳ xung nhịp clock ở phần cứng.

### 2.3. Bộ sinh Testcase tự động (`testcase_generator.py`)
Bộ sinh testcase tạo ra chuỗi **550 vector kích thích** bao gồm 8 kịch bản toàn diện:
* **Scenario 1 (Reset Initialization):** Kiểm tra tính năng khởi tạo hệ thống khi kích hoạt Reset mức thấp (`rst_n = 0`), đưa thang máy về Tầng 1 an toàn.
* **Scenario 2 (Single Floor Call):** Kiểm tra di chuyển đơn tầng từ Tầng 1 lên Tầng 3, mở cửa 10 chu kỳ, đóng cửa 4 chu kỳ và về IDLE.
* **Scenario 3 (Call Current Floor):** Kiểm tra khi cabin đang ở Tầng 3 mà có khách bấm Tầng 3 -> Hệ thống mở cửa ngay lập tức không cần di chuyển.
* **Scenario 4 (Multi-call Downward):** Cabin ở Tầng 3, đồng thời xuất hiện gọi Tầng 2 và Tầng 1 -> Dừng phục vụ Tầng 2 trước, sau đó tiếp tục đi xuống Tầng 1.
* **Scenario 5 (Multi-call Upward):** Cabin ở Tầng 1, gọi đồng thời Tầng 2, 3, 4 -> Thang máy ghé tuần tự từng tầng theo đúng thuật toán LOOK.
* **Scenario 6 (Obstacle Safety):** Trong giai đoạn đóng cửa, kích hoạt `door_sensor = 1` -> Cửa lập tức mở lại và đóng lại an toàn sau khi hết vật cản.
* **Scenario 7 (Emergency Stop):** Khi đang di chuyển, kích hoạt nút dừng khẩn cấp -> Thang dừng, mở cửa thoát hiểm và xóa các lệnh chờ.
* **Scenario 8 (Random Stress Test):** 250 chu kỳ phát sinh ngẫu nhiên các xung bấm nút, cảm biến cửa và nút dừng khẩn cấp để kiểm tra độ bền, chứng minh hệ thống không bao giờ bị rơi vào trạng thái treo (Deadlock-Free).

---

## CHƯƠNG 3: THIẾT KẾ PHẦN CỨNG RTL THEO PHƯƠNG PHÁP TOP-DOWN

### 3.1. Sơ đồ khối tổng thể (Top-Down Block Diagram)
Hệ thống được tổ chức thành 6 module phân cấp:

```
+-----------------------------------------------------------------------------------+
|                                   elevator_top                                    |
|                                                                                   |
|  +--------------------+                                                           |
|  |  debounce_filter   | (Khử rung nút bấm)                                        |
|  +---------+----------+                                                           |
|            | w_clean_req_btn                                                      |
|            v                                                                      |
|  +--------------------+                     +--------------------+                |
|  |  request_manager   |<------------------->|    elevator_fsm    |                |
|  |  (Hàng đợi gọi)    |  effective_req,     |  (Máy trạng thái)  |                |
|  +--------------------+  clear_req_mask     +----+----------+----+                |
|                                                  |          |                     |
|                                                  v          v                     |
|                                             +---------+ +---------+               |
|                                             |  seg7_  | | Status  |               |
|                                             | decoder | |  LEDs   |               |
|                                             +---------+ +---------+               |
+-----------------------------------------------------------------------------------+
```

### 3.2. Chi tiết các Sub-module

#### A. Module `elevator_fsm` (Trung tâm điều khiển)
Quản lý 6 trạng thái của hệ thống bằng cú pháp Verilog chuẩn:
* Trạng thái `S_IDLE`: Kiểm tra các cờ yêu cầu `i_has_req_current`, `i_has_req_above`, `i_has_req_below` để quyết định mở cửa hoặc di chuyển.
* Trạng thái `S_MOVING_UP` & `S_MOVING_DOWN`: Đếm thời gian `MOVE_TICKS` để chuyển tầng; khi đến tầng tiếp theo kiểm tra có người cần xuống/lên hay không để mở cửa.
* Trạng thái `S_DOOR_OPEN`: Mở cửa và duy trì trong `DOOR_OPEN_TICKS`. Nếu hành khách nhấn lại nút tầng hiện tại, bộ đếm thời gian được nạp lại để giữ cửa mở thêm.
* Trạng thái `S_DOOR_CLOSING`: Kiểm tra tín hiệu `i_door_sensor`. Nếu phát hiện vật cản, chuyển ngược lại trạng thái `S_DOOR_OPEN` ngay tức thì.
* Trạng thái `S_EMERGENCY`: Ưu tiên ngắt cao nhất, luôn có thể kích hoạt từ bất kỳ trạng thái nào.

#### B. Module `request_manager` (Quản lý yêu cầu)
* Chốt các yêu cầu gọi tầng vào thanh ghi `o_pending_req`.
* Kết hợp các nút bấm tức thời trong chu kỳ thành `o_effective_req = o_pending_req | i_req_btn`.
* Sử dụng mạch tổ hợp tính toán các cờ định hướng `o_has_req_above`, `o_has_req_below`, `o_has_req_current` cho FSM.
* Xóa cờ yêu cầu tương ứng thông qua mặt nạ xóa `i_clear_req_mask` khi tầng đó đã được phục vụ.

#### C. Module `timer_controller` (Bộ định thời)
* Đếm số xung clock và xuất các cờ báo hoàn thành: `o_move_done`, `o_door_open_done`, `o_door_close_done`.
* Cho phép cấu hình linh hoạt thông qua các tham số (parameters).

#### D. Module `seg7_decoder` (Giải mã LED 7 đoạn)
* Hiển thị số tầng hiện tại (`1`, `2`, `3`, `4`) theo chuẩn LED Cathode chung Active-Low (Lab 6 môn FAP201):
  * Tầng 1: `7'b1111001`
  * Tầng 2: `7'b0100100`
  * Tầng 3: `7'b0110000`
  * Tầng 4: `7'b0011001`
* Khi ở chế độ sự cố khẩn cấp (`EMERGENCY`), tự động hiển thị ký tự `E` (`7'b0000110`).

#### E. Module `debounce_filter` (Bộ lọc chống rung)
* Đếm ổn định tín hiệu ngõ vào trong `DEBOUNCE_LIMIT` chu kỳ trước khi xác nhận chuyển mức logic.
* Giúp loại bỏ hoàn toàn hiện tượng rung cơ học của nút nhấn vật lý trên kit FPGA.

---

## CHƯƠNG 4: MÔ PHỎNG & ĐỐI SOÁT TƯƠNG ĐƯƠNG (VERIFICATION)

### 4.1. Thiết kế Testbench tự động (`elevator_top_tb.v`)
* Testbench tạo xung clock 100MHz (chu kỳ 10ns).
* Sử dụng hàm `$fopen`, `$fgets`, `$sscanf` để đọc tuần tự từng dòng kích thích từ `testbench/stimulus.txt`.
* Đặt tín hiệu vào trước sườn âm (`negedge clk`) và lấy mẫu đầu ra sau sườn dương (`posedge clk #1`).
* Xuất toàn bộ dữ liệu ghi nhận được ra file `testbench/rtl_output.txt`.

### 4.2. Kết quả kiểm chứng tự động (Script `verify_results.py`)
Script so sánh tự động đọc cả hai file kết quả và thực hiện đối soát 5 trường tín hiệu: `current_floor`, `state`, `door_open`, `direction`, `pending_req`:

```text
=========================================================================
         FAP201 - RTL VS GOLDEN MODEL EQUIVALENCE CHECKER                
=========================================================================
Golden vector count : 550
RTL vector count    : 550

*************************************************************************
   [PASSED] 100% MATCH! ALL SIGNALS MATCH GOLDEN MODEL EXACTLY!          
   Total verified cycles: 550 cycles
*************************************************************************
```

**Đánh giá:** Toàn bộ 550 chu kỳ kiểm thử khớp 100% với Golden Model, không có bất kỳ sai lệch tín hiệu nào (0 Mismatches).

---

## CHƯƠNG 5: HIỆN THỰC HÓA VÀ ÁNH XẠ CHÂN TRÊN KIT FPGA GOWIN

### 5.1. Thiết bị mục tiêu
* **Chip FPGA:** Gowin GW5A-LV25UG324C2/I1
* **Kit phát triển:** Xiaomeige ACG525 Gowin FPGA Board
* **Tần số thạch anh:** 50 MHz (Chân `T9`)

### 5.2. Bảng ánh xạ chân vật lý (`elevator_pins.cst`)

| Tên cổng RTL | Hướng | Chân FPGA | Thiết bị vật lý trên Kit |
| :--- | :---: | :---: | :--- |
| `i_clk` | Input | **T9** | Xung clock 50MHz |
| `i_rst_n` | Input | **B16** | Nút nhấn KEY0 (Active-Low) |
| `i_req_btn[0]` | Input | **A15** | Nút nhấn KEY1 (Gọi Tầng 1) |
| `i_req_btn[1]` | Input | **C15** | Nút nhấn KEY2 (Gọi Tầng 2) |
| `i_req_btn[2]` | Input | **J14** | Chân GPIO mở rộng (Gọi Tầng 3) |
| `i_req_btn[3]` | Input | **H14** | Chân GPIO mở rộng (Gọi Tầng 4) |
| `i_door_sensor`| Input | **G14** | Cảm biến vật cản chống kẹt cửa |
| `i_emergency_btn` | Input | **F14** | Nút dừng khẩn cấp |
| `o_led_floor[0]` | Output | **D14** | LED0 (Báo Tầng 1) |
| `o_led_floor[1]` | Output | **C14** | LED1 (Báo Tầng 2) |
| `o_led_floor[2]` | Output | **B9**  | LED2 (Báo Tầng 3) |
| `o_led_floor[3]` | Output | **A9**  | LED3 (Báo Tầng 4) |
| `o_led_door` | Output | **E15** | LED báo trạng thái cửa mở |
| `o_led_emergency` | Output | **D15** | LED báo chế độ khẩn cấp |
| `o_led_dir_up` | Output | **B14** | LED báo thang máy đi lên |
| `o_led_dir_down`| Output | **A14** | LED báo thang máy đi xuống |

---

## CHƯƠNG 6: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN

### 6.1. Kết luận
* Đồ án đã hoàn thành xuất sắc toàn bộ các mục tiêu đặt ra theo yêu cầu môn học FAP201:
  1. Xây dựng hoàn chỉnh mô hình tham chiếu **Golden Model bằng Python**, hỗ trợ sinh testcase tự động với 8 kịch bản bao quát 100% trạng thái FSM.
  2. Thiết kế phần cứng **RTL theo mô hình Top-Down** bằng Verilog HDL chuẩn mực, tối ưu thuật toán lập lịch **LOOK/SCAN** và đảm bảo các tiêu chuẩn an toàn thực tế.
  3. Xây dựng **Self-checking Testbench** và bộ công cụ tự động hóa mô phỏng trên **ModelSim**, đạt tỉ lệ tương đương **100% (550/550 chu kỳ)** với Golden Model.
  4. Đóng gói mã nguồn chuẩn hóa cho kho lưu trữ **GitHub** và cung cấp đầy đủ file ràng buộc chân cho kit FPGA **Gowin GW5A**.

### 6.2. Hướng phát triển mở rộng
* Nâng cấp hệ thống lên bộ điều khiển thang máy đôi (Dual-Elevator Dispatcher) với thuật toán phân phối tải tối ưu.
* Tích hợp giao tiếp UART / Ethernet để truyền dữ liệu trạng thái thang máy lên máy tính giám sát từ xa (SCADA).
* Bổ sung cảm biến trọng lượng cabin để báo quá tải (Overload alarm).
