# 홀드 탐지 및 자세 분석 기반 클라이밍 문제 풀이 영상 검색 시스템

## 프로젝트 소개  
홀드 감지와 자세 분석을 기반으로 사용자가 업로드한 클라이밍 문제 사진과 인스타그램 내 실제 등반 영상 간의 유사도를 계산하여, 유사한 문제 풀이 영상을 자동 추천하는 시스템입니다.



## 상세 소개  
실내 클라이밍 문제 해결을 돕기 위해, 사용자가 클라이밍장 벽면 사진을 업로드하면 자동으로 홀드를 탐지합니다. 사용자는 실제 문제에 해당하는 홀드를 선택하고, 시스템은 인스타그램에서 해당 홀드를 포함한 등반 영상들을 수집 및 분석합니다. Google MediaPipe를 이용한 관절 추정과 Roboflow 기반 홀드 탐지를 결합해, 영상 속 등반자의 동작과 홀드 사용 정보를 정량적으로 비교합니다. 이를 통해 사용자가 업로드한 문제와 유사한 영상들을 자동으로 추천하며, 클라이머들이 효율적으로 풀이 방법을 참고할 수 있도록 지원합니다.


## 주요 기능  
- 클라이밍장 위치 검색 및 문제 사진 업로드  
- Roboflow 모델을 활용한 홀드 자동 탐지  
- 사용자가 문제에 해당하는 홀드 직접 선택  
- 인스타그램 영상 자동 수집 및 다운로드 (Selenium + Instaloader)  
- MediaPipe 기반 관절 추정과 홀드 위치 비교  
- spatiogram 유사도 알고리즘을 활용한 문제-영상 간 유사도 계산 및 추천



## 개발환경  
- Backend: Python (Flask, Selenium, Instaloader)  
- AI/ML: Roboflow (YOLO 기반 객체 탐지), MediaPipe Pose  
- 유사도 분석: OpenCV, NumPy 기반 spatiogram 알고리즘  
- 프론트엔드: Flutter Web (사용자 인터페이스)


## 주의사항  
- 인스타그램 영상 분석은 카메라가 고정된 영상에 한해 정확한 결과를 보장합니다.  
- 영상 수집 및 분석 과정에서 Instagram 로그인 상태 유지가 필요합니다.  
- 시스템 실행을 위해 관련 API 키 및 크롬 드라이버 설정이 필요합니다.


## 외부 링크  
- 프로젝트 데모 영상 (예시): https://youtube.com/shorts/ir2oAdScB84?feature=share
