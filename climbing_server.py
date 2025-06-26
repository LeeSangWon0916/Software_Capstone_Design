from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from PIL import Image, ImageDraw
import io
import os
import cv2
import numpy as np
from roboflow import Roboflow
import copy
import base64
from datetime import datetime

app = Flask(__name__)
CORS(app)

RESULT_FOLDER = "results"
os.makedirs(RESULT_FOLDER, exist_ok=True)

rf = Roboflow(api_key="EPZkkKsr1QzoKo0Znukk")
project = rf.workspace("spraywall-id").project("climbing-rv6vd")
model = project.version("2").model

# 전역 변수로 이미지 및 박스 정보 저장
last_image_cv = None
last_hold_rects = []

@app.route('/upload', methods=['POST'])
def detect_holds():
    global last_image_cv, last_hold_rects

    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400

    file = request.files['image']
    image_bytes = file.read()
    image = Image.open(io.BytesIO(image_bytes))

    if image.mode == 'RGBA':
        image = image.convert('RGB')

    img_cv = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)

    temp_path = "temp.jpg"
    cv2.imwrite(temp_path, img_cv)

    prediction = model.predict(temp_path, confidence=20)
    hold_boxes = prediction.json()['predictions']

    hold_rects = []
    for obj in hold_boxes:
        x, y, w, h = obj["x"], obj["y"], obj["width"], obj["height"]
        scale = 0.8
        w *= scale
        h *= scale
        x1, y1 = int(x - w / 2), int(y - h / 2)
        x2, y2 = int(x + w / 2), int(y + h / 2)
        hold_rects.append(((x1, y1, x2, y2), obj["class"]))

    # ⚠️ 박스 그리기 전에 원본 저장
    last_image_cv = np.array(img_cv)
    last_hold_rects = hold_rects

    # 박스 그리기용 복사본
    img_with_boxes = img_cv.copy()

    for (x1, y1, x2, y2), _ in hold_rects:
        cv2.rectangle(img_with_boxes, (x1, y1), (x2, y2), (0, 255, 0), 2)

    result_path = os.path.join(RESULT_FOLDER, "result.jpg")
    cv2.imwrite(result_path, img_with_boxes)

    return jsonify({
        "message": "Detection complete",
        "image_url": "http://192.168.123.103:5000/results/result.jpg",
        "boxes": [
            {"x1": x1, "y1": y1, "x2": x2, "y2": y2}
            for ((x1, y1, x2, y2), _) in hold_rects
        ],
        "image_size": {"width": image.width, "height": image.height}
    })

@app.route('/process_selected', methods=['POST'])
def process_selected():
    global last_image_cv, last_hold_rects

    if last_image_cv is None or not last_hold_rects:
        return jsonify({'error': 'No image previously uploaded'}), 400

    data = request.get_json()
    selected_indices = data.get('selected_indices', [])

    for idx in selected_indices:
        if 0 <= idx < len(last_hold_rects):
            x1, y1, x2, y2 = last_hold_rects[idx][0]
            cv2.rectangle(last_image_cv, (x1, y1), (x2, y2), (0, 0, 255), 2)

    result_path = os.path.join(RESULT_FOLDER, "selected_result.jpg")
    cv2.imwrite(result_path, last_image_cv)

    return jsonify({
        "message": "Selected boxes drawn",
        "image_url": "http://192.168.123.103:5000/results/selected_result.jpg",
    })

@app.route('/mask', methods=['POST'])
def mask_image():
    data = request.get_json()
    image_data = base64.b64decode(data['image'])
    boxes = data['boxes']

    # Load image
    image = Image.open(io.BytesIO(image_data)).convert("RGB")
    masked_image = Image.new("RGB", image.size, (255, 255, 255))  # 흰색 배경

    MARGIN = -3  # 픽셀 단위로 확장

    for box in boxes:
        # MARGIN만큼 확장하되 이미지 경계를 벗어나지 않도록 처리
        x1 = max(int(box['x1']) - MARGIN, 0)
        y1 = max(int(box['y1']) - MARGIN, 0)
        x2 = min(int(box['x2']) + MARGIN, image.width)
        y2 = min(int(box['y2']) + MARGIN, image.height)

        # 확장된 영역을 잘라서 붙임
        region = image.crop((x1, y1, x2, y2))
        masked_image.paste(region, (x1, y1))

    # 결과 이미지 저장 (여기 추가!)
    save_dir = "C:/Users/사용자"
    os.makedirs(save_dir, exist_ok=True)
    filename = f"masked_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
    masked_image_path = os.path.join(save_dir, filename)
    masked_image.save(masked_image_path)

    # Encode result
    buffered = io.BytesIO()
    masked_image.save(buffered, format="PNG")
    encoded_img = base64.b64encode(buffered.getvalue()).decode()

    return jsonify({'masked_image': encoded_img})



@app.route('/results/<filename>')
def serve_result_image(filename):
    return send_from_directory(RESULT_FOLDER, filename)

def compute_spatiogram(image, bins_h, bins_s, bins_v, ignore_white=True):
    height, width, _ = image.shape
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

    mask = np.ones((height, width), dtype=np.uint8)
    if ignore_white:
        s = hsv[:, :, 1]
        v = hsv[:, :, 2]
        mask = np.where(((s < 20) & (v > 200)) | (v < 30), 0, 1).astype(np.uint8)

    moments = cv2.moments(mask.astype(np.uint8))
    cx = moments['m10'] / (moments['m00'] + 1e-6)
    cy = moments['m01'] / (moments['m00'] + 1e-6)

    spatiogram = {}
    bin_size_h = 180 // bins_h
    bin_size_s = 256 // bins_s
    bin_size_v = 256 // bins_v

    for y in range(height):
        for x in range(width):
            if mask[y, x] == 0:
                continue

            h, s, v = hsv[y, x]
            bin_h = min(h // bin_size_h, bins_h - 1)
            bin_s = min(s // bin_size_s, bins_s - 1)
            bin_v = min(v // bin_size_v, bins_v - 1)
            bin_idx = (int(bin_h), int(bin_s), int(bin_v))

            if bin_idx not in spatiogram:
                spatiogram[bin_idx] = {'count': 0, 'positions': []}

            spatiogram[bin_idx]['count'] += 1
            norm_x = (x - cx) / width
            norm_y = (y - cy) / height
            spatiogram[bin_idx]['positions'].append((norm_x, norm_y))

    for bin_idx in spatiogram:
        positions = np.array(spatiogram[bin_idx]['positions'])
        mean = np.mean(positions, axis=0)
        spatiogram[bin_idx]['mean'] = mean

    return spatiogram, cx, cy


def sim(sp1, sp2, sigma):
    if not sp1 or not sp2:
        return 0.0

    def get_sorted_bins(sp):
        return sorted(sp.items(), key=lambda item: item[1]['count'], reverse=True)

    sorted_bins1 = get_sorted_bins(sp1)
    sorted_bins2 = get_sorted_bins(sp2)

    def get_neighbors(sp, top_key):
        h, s, v = top_key
        neighbors = []
        for dh in [-1, 0, 1]:
            for ds in [-1, 0, 1]:
                for dv in [-1, 0, 1]:
                    if abs(dh) + abs(ds) + abs(dv) == 1:
                        neighbor_key = (h + dh, s + ds, v + dv)
                        if neighbor_key in sp:
                            neighbors.append((neighbor_key, sp[neighbor_key]))
        neighbors.append((top_key, sp[top_key]))
        return neighbors

    top_key1 = sorted_bins1[0][0]
    top_key2 = sorted_bins2[0][0]

    bins1 = get_neighbors(sp1, top_key1)
    bins2 = get_neighbors(sp2, top_key2)

    max_similarity = 0.0

    for (h1, s1, v1), b1 in bins1:
        for (h2, s2, v2), b2 in bins2:
            mu1 = b1['mean']
            mu2 = b2['mean']

            dist2 = np.sum((mu1 - mu2) ** 2)
            color_dist2 = (h1 - h2) ** 2 + (s1 - s2) ** 2 + (v1 - v2) ** 2

            color_weight = np.exp(-color_dist2 / (2 * 1.0 ** 2))
            spatial_term = np.exp(-dist2 / (8 * sigma ** 2))

            similarity = spatial_term * color_weight
            max_similarity = max(max_similarity, similarity)

    return min(max_similarity, 1.0)

COMPARE_DIR = 'compare_targets'  # 비교 대상 이미지 폴더
STATIC_DIR = 'static'
THUM_DIR = 'thum'

@app.route('/compare', methods=['POST'])
def compare_images():
    data = request.get_json()
    image_data = base64.b64decode(data['image'])
    boxes = data['boxes']

    # 1. 마스킹된 이미지 생성
    image = Image.open(io.BytesIO(image_data)).convert("RGB")
    masked_image = Image.new("RGB", image.size, (255, 255, 255))
    for box in boxes:
        x1 = max(0, int(box['x1']) + 4)
        y1 = max(0, int(box['y1']) + 4)
        x2 = min(image.width, int(box['x2']) - 4)
        y2 = min(image.height, int(box['y2']) - 4)
        region = image.crop((x1, y1, x2, y2))
        masked_image.paste(region, (x1, y1))

    # numpy로 변환 (BGR로)
    masked_np = cv2.cvtColor(np.array(masked_image), cv2.COLOR_RGB2BGR)
    masked_np = cv2.resize(masked_np, (256, 256))
    cv2.imwrite("masked_output.jpg", masked_np)
    image1 = cv2.imread("masked_output.jpg")
    sp1, _, _ = compute_spatiogram(image1, bins_h=8, bins_s=4, bins_v = 4)

    # 2. 비교 대상들과 유사도 계산
    results = []
    for filename in os.listdir(COMPARE_DIR):
        path = os.path.join(COMPARE_DIR, filename)
        if not filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            continue
        image2 = cv2.imread(path)
        if image2 is None:
            continue
        image2 = cv2.resize(image2, (256, 256))
        sp2, _, _ = compute_spatiogram(image2, bins_h=8, bins_s=4, bins_v=4)

        # video 파일명 추출
        video_name = filename.replace('used_holds_', '').replace('.jpg', '.mp4')

        similarity = sim(sp1, sp2, sigma=0.05)
        results.append({
            'filename': filename,  # static에서 접근 가능해야 함
            'video': video_name,
            'similarity': round(similarity, 4)
        })

    # 유사도 높은 순 정렬
    results.sort(key=lambda x: -x['similarity'])

    return jsonify({'results': results})

# 이미지 파일 제공 (static 폴더에서 serve)
@app.route('/static/<path:filename>')
def static_files(filename):
    return send_from_directory(STATIC_DIR, filename)

# 이미지 파일 제공 (static 폴더에서 serve)
@app.route('/thum/<path:filename>')
def thum_files(filename):
    return send_from_directory(THUM_DIR, filename)

@app.route('/video/<path:filename>')
def serve_video(filename):
    return send_from_directory('video', filename)


if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)

