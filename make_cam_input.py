import re

def rgb888_to_rgb565_bytes(hex_str):
    """
    RGB888 Hex 문자열을 입력받아 (예: "362A23")
    RGB565 포맷의 High Byte와 Low Byte로 변환하여 반환합니다.
    """
    try:
        val = int(hex_str, 16)
    except ValueError:
        return None, None

    r = (val >> 16) & 0xFF
    g = (val >> 8) & 0xFF
    b = val & 0xFF

    # RGB565 변환: R(5), G(6), B(5)
    r5 = (r >> 3) & 0x1F
    g6 = (g >> 2) & 0x3F
    b5 = (b >> 3) & 0x1F
    
    rgb565 = (r5 << 11) | (g6 << 5) | b5

    # High Byte / Low Byte 분리
    byte_high = (rgb565 >> 8) & 0xFF
    byte_low = rgb565 & 0xFF
    
    return byte_high, byte_low

def convert_coe_to_mem(input_filename, output_filename):
    print(f"Reading {input_filename}...")
    
    try:
        with open(input_filename, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: {input_filename} 파일을 찾을 수 없습니다.")
        return

    # 데이터 추출: memory_initialization_vector= 뒤에 오는 데이터들을 찾습니다.
    # 쉼표(,)나 세미콜론(;)으로 구분된 16진수 값들을 모두 찾습니다.
    
    # 먼저 벡터 시작 지점을 찾습니다.
    start_match = re.search(r'memory_initialization_vector\s*=\s*', content, re.IGNORECASE)
    if not start_match:
        print("Error: COE 파일 형식이 올바르지 않습니다. (memory_initialization_vector를 찾을 수 없음)")
        return

    # 데이터 부분만 잘라냅니다.
    data_content = content[start_match.end():]
    
    # 쉼표, 세미콜론, 공백 등을 제거하고 순수 데이터만 리스트로 만듭니다.
    # 정규식: 16진수 문자열 (0-9, A-F) 6자리 찾기
    hex_values = re.findall(r'[0-9A-Fa-f]{6}', data_content)

    output_lines = []
    
    print(f"Found {len(hex_values)} pixels. Converting...")

    for hex_val in hex_values:
        high, low = rgb888_to_rgb565_bytes(hex_val)
        
        if high is not None:
            # Verilog $readmemh가 읽기 편하게 바이트 단위로 줄바꿈하여 저장
            output_lines.append(f"{high:02X}")
            output_lines.append(f"{low:02X}")

    # 결과 저장
    with open(output_filename, 'w') as f:
        # 주석 추가 (선택 사항)
        # f.write("// Converted from COE. Format: RGB565 HighByte, LowByte\n")
        f.write("\n".join(output_lines))

    print(f"Success! Converted data saved to {output_filename}")
    print(f"Total Bytes: {len(output_lines)} (Pixels: {len(output_lines)//2})")

if __name__ == "__main__":
    # 사용 방법:
    # 1. 변환할 COE 파일 이름을 'input.coe'로 저장하거나 아래 이름을 변경하세요.
    input_file = "./output.coe"   # <-- 여기에 가지고 계신 coe 파일명을 넣으세요
    output_file = "cam_input_data.mem"
    
    convert_coe_to_mem(input_file, output_file)