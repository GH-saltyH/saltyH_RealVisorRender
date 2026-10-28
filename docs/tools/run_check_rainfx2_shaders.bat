@echo off
rem 터미널 창 인코딩을 UTF-8로 설정하여 한글 깨짐을 방지합니다.
chcp 65001 >nul

:START
cls
echo ===================================================
echo  check_rainfx2_shaders.py 스크립트를 실행합니다...
echo ===================================================
echo.

rem 파이썬 스크립트 실행
python check_rainfx2_shaders.py

echo.
echo ===================================================
echo  스크립트 실행이 완료되었습니다.
echo ===================================================
echo.

:CHOICE
rem 사용자에게 재실행 여부 묻기 (Y/N)
set /p ANSWER="다시 실행하시겠습니까? (Y/N): "

rem 입력값의 공백 제거 및 대문자 변환 처리를 위해 IF 조건문 구성
if /i "%ANSWER%"=="Y" goto START
if /i "%ANSWER%"=="N" goto END

rem Y나 N이 아닌 다른 키를 눌렀을 때의 예외 처리
echo 잘못된 입력입니다. Y 또는 N을 입력해주세요.
echo.
goto CHOICE

:END
echo.
echo 프로그램을 종료합니다. 터미널을 닫으려면 아무 키나 누르세요...
pause >nul
exit
