import os
import time
import requests
import numpy as np
import cv2
import csv

import instaloader
from instaloader import Post

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

import mediapipe as mp
from roboflow import Roboflow

from climbing_server import compute_spatiogram

# 경로 설정
video_folder = r"C:/Users/사용자/video"
save_folder1 = r"compare_targets"
save_folder2 = r"static"
os.makedirs(video_folder, exist_ok=True)
os.makedirs(save_folder1, exist_ok=True)
os.makedirs(save_folder2, exist_ok=True)

csv_path = "video_info.csv"

# Roboflow 모델 초기화
rf = Roboflow(api_key="EPZkkKsr1QzoKo0Znukk")
project = rf.workspace("spraywall-id").project("climbing-rv6vd")
model = project.version("2").model

# Mediapipe 초기화
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(static_image_mode=False, model_complexity=2)
KEYPOINTS = [
    mp_pose.PoseLandmark.LEFT_WRIST,
    mp_pose.PoseLandmark.RIGHT_WRIST,
    #mp_pose.PoseLandmark.LEFT_ANKLE,
    #mp_pose.PoseLandmark.RIGHT_ANKLE
]

# 영상 정보 저장 함수
def save_video_info(image_name, post_url, video_index=None):
    if not os.path.exists("video_info.csv"):
        with open("video_info.csv", mode='w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['image_name', 'instagram_post_url'])

    with open("video_info.csv", mode='a', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        if video_index is not None:
            post_url = f"{post_url}?img_index={video_index}"
        writer.writerow([image_name, post_url])

# 영상 분석 함수
def process_video(video_path, save_name, post_url, video_index=None, num_frames=5):

    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    sampled_indices = np.linspace(0, total_frames - 1, num=num_frames, dtype=int)

    ret, frame = cap.read()
    if not ret:
        print(f"❌ 첫 프레임 읽기 실패: {video_path}")
        return

    frame_height, frame_width, _ = frame.shape
    white_background = np.ones((frame_height, frame_width, 3), dtype=np.uint8) * 255
    white_backgrounds = np.ones((frame_height, frame_width, 3), dtype=np.uint8) * 255
    white_backgroundss = np.ones((frame_height, frame_width, 3), dtype=np.uint8) * 255
    final_backgrounds = np.ones((frame_height, frame_width, 3), dtype=np.uint8) * 255


    for frame_index in sampled_indices:

        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        ret, frame = cap.read()
        if not ret:
            continue

        temp_path = f"temp_frame.jpg"

        cv2.imwrite(temp_path, frame)
        prediction = model.predict(temp_path, confidence=50)
        hold_boxes = prediction.json()['predictions']

        for obj in hold_boxes:
            x, y, w, h = obj["x"], obj["y"], obj["width"], obj["height"]
            x1, y1 = int(x - w / 2), int(y - h / 2)
            x2, y2 = int(x + w / 2), int(y + h / 2)
            hold_crop = frame[y1:y2, x1:x2]

            if hold_crop.size > 0:
                try:
                    white_background[y1:y2, x1:x2] = np.where(
                        hold_crop < 250, hold_crop, white_background[y1:y2, x1:x2]
                    )
                except:
                    continue

    final_path = f"entire_holdmap_{video_index}.jpg"
    cv2.imwrite(final_path, white_background)
    final_prediction = model.predict(final_path, confidence=60)
    final_hold_boxes = final_prediction.json()['predictions']

    hold_rects = []
    for obj in final_hold_boxes:
        x, y, w, h = obj["x"], obj["y"], obj["width"], obj["height"]
        scale = 0.7
        w *= scale
        h *= scale
        x1, y1 = int(x - w / 2), int(y - h / 2)
        x2, y2 = int(x + w / 2), int(y + h / 2)
        # 🔴 빨간 테두리 그리기 (얇게)
        #cv2.rectangle(white_background, (x1, y1), (x2, y2), (0, 0, 255), 1)
        hold_rects.append(((x1, y1, x2, y2), obj["class"]))

    hold_overlap_counts = {idx: 0 for idx in range(len(hold_rects))}
    hold_overlap_counts_ankle = {idx: 0 for idx in range(len(hold_rects))}
    frame_index = 0
    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)


    hold_rects_for_pose = []
    for obj in final_hold_boxes:
        x, y, w, h = obj["x"], obj["y"], obj["width"], obj["height"]
        scale = 1
        w *= scale
        h *= scale
        x1, y1 = int(x - w / 2), int(y - h / 2)
        x2, y2 = int(x + w / 2), int(y + h / 2)
        # 🔴 빨간 테두리 그리기 (얇게)
        #cv2.rectangle(white_background, (x1, y1), (x2, y2), (0, 0, 255), 1)
        hold_rects_for_pose.append(((x1, y1, x2, y2), obj["class"]))





    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if frame_index % int(fps / 3) == 0:
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result = pose.process(frame_rgb)
            if result.pose_landmarks:
                for kp in KEYPOINTS:
                    lm = result.pose_landmarks.landmark[kp]
                    x = int(lm.x * frame_width)
                    y = int(lm.y * frame_height)

                    # 🔴 손발 위치에 빨간 점 표시
                    #cv2.circle(white_background, (x, y), 3, (0, 0, 255), -1)

                    for idx, (rect, _) in enumerate(hold_rects_for_pose):
                        x1, y1, x2, y2 = rect
                        if x1 <= x <= x2 and y1 <= y <= y2:
                            hold_overlap_counts[idx] += 1

                
                for kp in [mp_pose.PoseLandmark.LEFT_ANKLE, mp_pose.PoseLandmark.RIGHT_ANKLE]:
                    lm = result.pose_landmarks.landmark[kp]
                    x = int(lm.x * frame_width)
                    y = int(lm.y * frame_height)

                    #cv2.circle(white_background, (x, y), 3, (0, 255, 0), -1)

                    for idx, (rect, _) in enumerate(hold_rects_for_pose):
                        x1, y1, x2, y2 = rect
                        if x1 <= x <= x2 and y1 <= y <= y2:
                            hold_overlap_counts_ankle[idx] += 1



        frame_index += 1

    cv2.imwrite(f"pose_check_{save_name}.jpg", white_background)

    used_hold_indices = {idx for idx, count in hold_overlap_counts.items() if count >= 10}
    for idx in used_hold_indices:
        (x1, y1, x2, y2), _ = hold_rects[idx]
        width = x2 - x1
        height = y2 - y1
        pad_x = 0 # int(width * 0.1)
        pad_y = 0 # int(height * 0.1)
        x1 = max(x1 + pad_x, 0)
        y1 = max(y1 + pad_y, 0)
        x2 = min(x2 - pad_x, frame_width)
        y2 = min(y2 - pad_y, frame_height)
        cropped_hold = white_background[y1:y2, x1:x2]
        white_backgrounds[y1:y2, x1:x2] = cropped_hold

    print(len(used_hold_indices))

    cap.release()

    cv2.imwrite(f"five_{save_name}.jpg", white_backgrounds)

    img = cv2.imread(f"five_{save_name}.jpg")
    hsv_img = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv_img)

    bins_h, bins_s, bins_v= 8, 4, 2
    h_bin = (h.astype(int) * bins_h // 180)
    s_bin = (s.astype(int) * bins_s // 256)
    v_bin = (v.astype(int) * bins_v // 256)

    sp1, _, _ = compute_spatiogram(img, bins_h, bins_s, bins_v)

    #dominant_bin = max(sp1.items(), key=lambda item: item[1]['count'])[0]

    #used_hold_indices = {idx for idx, count in hold_overlap_counts.items() if count >= 3}
    for idx in used_hold_indices:
        (x1, y1, x2, y2), _ = hold_rects[idx]
        width = x2 - x1
        height = y2 - y1
        pad_x = 0 # int(width * 0.1)
        pad_y = 0 # int(height * 0.1)
        x1 = max(x1 + pad_x, 0)
        y1 = max(y1 + pad_y, 0)
        x2 = min(x2 - pad_x, frame_width)
        y2 = min(y2 - pad_y, frame_height)
        cropped_hold = white_background[y1:y2, x1:x2]
        white_backgroundss[y1:y2, x1:x2] = cropped_hold
        cv2.rectangle(white_backgroundss, (x1, y1), (x2, y2), (0, 0, 255), 1)
    
    print(len(used_hold_indices))
    
    cv2.imwrite(f"three_count_{save_name}.jpg", white_backgroundss)

    img_ = cv2.imread(f"three_count_{save_name}.jpg")
    hsv = cv2.cvtColor(img_, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)

    print("hsv : ", h, s, v)

    h_bin = (h.astype(int) * bins_h // 180)
    s_bin = (s.astype(int) * bins_s // 256)
    v_bin = (v.astype(int) * bins_v // 256)

    print("hsv bin : " , h_bin, s_bin, v_bin)

    # dominant bin 세 개 구하기
    top_3_bins = sorted(sp1.items(), key=lambda item: item[1]['count'], reverse=True)[:5]
    top_3_counts = [(k, v['count']) for k, v in top_3_bins]
    print(top_3_counts)
    top_3_bin_keys = [bin_key for bin_key, _ in top_3_bins]


    # 각 bin이 얼마나 많은 홀드에 포함되어 있는지 계산
    bin_to_hold_count = {bin_key: 0 for bin_key in top_3_bin_keys}

    for bin_key in top_3_bin_keys:
        h_val, s_val, v_val = bin_key
        bin_mask = (h_bin == h_val) & (s_bin == s_val) & (v_bin == v_val)

        # 마스크를 0~255 범위의 uint8 이미지로 변환
        mask_img = (bin_mask.astype(np.uint8)) * 255


        # 저장
        filename = f"bin_mask_{save_name}_{h_val}_{s_val}_{v_val}.png"
        cv2.imwrite(filename, mask_img)

        print(f"{filename} 포함 픽셀 수:", np.sum(bin_mask))

        if np.sum(bin_mask) > 10000:
            continue

        for idx in used_hold_indices:
            (x1, y1, x2, y2), _ = hold_rects[idx]
            bin_crop = bin_mask[y1:y2, x1:x2]
            if np.count_nonzero(bin_crop) >= 10:
                bin_to_hold_count[bin_key] += 1
    print(bin_to_hold_count)

    # 💡 최대값 후보들 찾기
    max_count = max(bin_to_hold_count.values())
    candidates = [bin_key for bin_key, count in bin_to_hold_count.items() if count == max_count]

    # 🎯 후보가 여러 개면 h값이 가장 많이 등장하는 쪽 선택
    if len(candidates) == 1:
        dominant_bin = candidates[0]
    else:
        # h값 등장 횟수 세기
        h_count = {}
        for h_val, _, _ in candidates:
            h_count[h_val] = h_count.get(h_val, 0) + 1
        max_h = max(h_count.items(), key=lambda item: item[1])[0]

        # h값이 같은 후보 중 가장 먼저 나오는 걸 선택
        for bin_key in candidates:
            if bin_key[0] == max_h:
                dominant_bin = bin_key
                break

    print("🎯 최종 dominant_bin:", dominant_bin)


    # dominant bin mask 생성
    '''dominant_bin_mask = (
        (h_bin == dominant_bin[0]) &
        (s_bin == dominant_bin[1]) &
        (v_bin == dominant_bin[2])
)'''







    #dominant_bin_mask = (h_bin == dominant_bin[0]) & (s_bin == dominant_bin[1]) & (v_bin == dominant_bin[2])

    # 🔁 dominant bin과 겹치는 픽셀이 5개 이상인 경우만 남기기
    used_hold_indices = {
    idx for idx, count in hold_overlap_counts.items() if count >= 1
    } | {
    idx for idx, count in hold_overlap_counts_ankle.items() if count >= 1
    }

    white_background_test = np.ones((frame_height, frame_width, 3), dtype=np.uint8) * 255

    for idx in used_hold_indices:
        (x1, y1, x2, y2), _ = hold_rects[idx]
        width = x2 - x1
        height = y2 - y1
        pad_x = 0 # int(width * 0.1)
        pad_y = 0 # int(height * 0.1)
        x1 = max(x1 + pad_x, 0)
        y1 = max(y1 + pad_y, 0)
        x2 = min(x2 - pad_x, frame_width)
        y2 = min(y2 - pad_y, frame_height)
        cropped_hold = white_background[y1:y2, x1:x2]
        white_background_test[y1:y2, x1:x2] = cropped_hold

    cv2.imwrite(f"test_ankle_{save_name}.jpg", white_background_test)

    img_ = cv2.imread(f"test_ankle_{save_name}.jpg")
    hsv = cv2.cvtColor(img_, cv2.COLOR_BGR2HSV)
    h, s, v = cv2.split(hsv)

    h_bin = (h.astype(int) * bins_h // 180)
    s_bin = (s.astype(int) * bins_s // 256)
    v_bin = (v.astype(int) * bins_v // 256)

     # dominant bin mask 생성
    dominant_bin_mask = (
        (h_bin == dominant_bin[0]) &
        (s_bin == dominant_bin[1]) &
        (v_bin == dominant_bin[2])
    )   


    print(len(used_hold_indices))

    filtered_indices = set()
    for idx in used_hold_indices:
        (x1, y1, x2, y2), _ = hold_rects[idx]
        bin_match_crop = dominant_bin_mask[y1:y2, x1:x2]
        match_count = np.count_nonzero(bin_match_crop)
        print("match : ", match_count)
        if match_count >= 30:
            filtered_indices.add(idx)
    print(len(filtered_indices))

    # 🔲 해당 홀드만 최종 이미지에 반영
    for idx in filtered_indices:
        (x1, y1, x2, y2), _ = hold_rects[idx]
        width = x2 - x1
        height = y2 - y1
        pad_x = 0 # int(width * 0.1)
        pad_y = 0 # int(height * 0.1)
        x1 = max(x1 + pad_x, 0)
        y1 = max(y1 + pad_y, 0)
        x2 = min(x2 - pad_x, frame_width)
        y2 = min(y2 - pad_y, frame_height)
        cropped_hold = white_background[y1:y2, x1:x2]
        final_backgrounds[y1:y2, x1:x2] = cropped_hold

    folders = ["static", "compare_targets"]

    for folder in folders:
        save_path = os.path.join(folder, f"used_holds_{save_name}.jpg")
        cv2.imwrite(save_path, final_backgrounds)

    # 영상 정보 저장
    save_video_info(f"used_holds_{save_name}.jpg", post_url, video_index)

    # 영상 삭제
    if os.path.exists(video_path):
        os.remove(video_path)
        print(f"🗑️ 분석 후 영상 삭제: {video_path}")

# 스크래핑 함수
def scrape_location_posts(location_url, num_scrolls=0):
    options = webdriver.ChromeOptions()
    options.add_argument("user-data-dir=C:/Users/사용자/AppData/Local/Google/Chrome/NewProfile2")
    options.add_argument("profile-directory=Default")
    options.add_argument("--start-maximized")

    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    driver.get(location_url)
    time.sleep(3)
    for _ in range(num_scrolls):
        driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
        WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, 'a')))
        time.sleep(10)

    post_links = []
    elems = driver.find_elements(By.XPATH, "//*[contains(@class, 'x1i10hfl')]")
    for e in elems:
        href = e.get_attribute('href')
        if href and "/p/" in href:
            post_links.append(href)
    driver.quit()

    results = []
    for link in post_links:
        results.append([link, ""])
    return results

# 다운로드 및 분석 통합 함수
def download_and_process_videos(results):
    L = instaloader.Instaloader(save_metadata=False, download_comments=False)
    #L.login('onam1st_climb', 'awardcycle1519!')

    for post_url, _ in results:
        if "/p/" not in post_url:
            continue
        shortcode = post_url.split("/p/")[1].split("/")[0]
        save_name = shortcode

        already_analyzed = os.path.exists(os.path.join(save_folder1, f"used_holds_{save_name}.jpg"))
        if already_analyzed:
            print(f"⏭️ 이미 분석됨, 스킵: {save_name}")
            continue

        try:
            post = Post.from_shortcode(L.context, shortcode)
            if post.is_video:
                video_url = post.video_url
                video_path = os.path.join(video_folder, f"{save_name}.mp4")
                if not os.path.exists(video_path):
                    video_bytes = requests.get(video_url).content
                    with open(video_path, "wb") as f:
                        f.write(video_bytes)
                    print(f"📥 다운로드 완료: {video_path}")
                # process_video(video_path, save_name, post_url)
            elif post.typename == "GraphSidecar":
                for idx, sidecar_node in enumerate(post.get_sidecar_nodes()):
                    if sidecar_node.is_video:
                        video_url = sidecar_node.video_url
                        short_id = f"{save_name}_video_{idx+1}"
                        video_path = os.path.join(video_folder, f"{short_id}.mp4")
                        if not os.path.exists(video_path):
                            video_bytes = requests.get(video_url).content
                            with open(video_path, "wb") as f:
                                f.write(video_bytes)
                            print(f"📥 멀티포스트 다운로드: {video_path}")
                        process_video(video_path, short_id, post_url, video_index=idx + 1)
        except Exception as e:
            print(f"⚠️ 오류 발생: {post_url} - {e}")

# 실행
if __name__ == "__main__":
    location_url = "https://www.instagram.com/explore/locations/132859156463624/-theclimb-sadang/recent/"
    post_list = scrape_location_posts(location_url, num_scrolls=0)
    '''post_list = [
                #['https://www.instagram.com/p/DJ1qJ86SOvb/?img_index=11&igsh=dDhhbGRvODlobTV1', ''],
                 #['https://www.instagram.com/p/DJ1dYHOP6cM/?img_index=9&igsh=Mms5M3hvYXhqOXB2', ''],
                 ['https://www.instagram.com/p/DJ0NeFuSYi_/?img_index=13&igsh=YWV6bWNkYWtqajA3', ''],
                 #['https://www.instagram.com/p/DJyz3lJyQNa/?img_index=4&igsh=MTB4dDlta2F5bXRjMg==', '']
                 ]'''

    download_and_process_videos(post_list)