# VoiceLoco Call SDK iOS Guide

## 설치

* **시스템 요구사항**

  iOS 10 이상을 지원하는 모든 iOS 디바이스

* **Import**

  VoiceLoco Call SDK를 사용하기 위해서는 아래의 파일을 프로젝트에 추가시켜줘야 합니다.
  ```
  Resiprocate.framework
  VLVoice.framework
  ```
  이 두 파일을 프로젝트 안에 복사 후 해당 프로젝트 세팅의 'Embbeded Binarie' 탭에 추가하면 VoiceLoco Call SDK 설정이 완료됩니다.

* **CocoaPod**

  ```
  pod 'VLVoice'
  ```

* **Carthage**
 
  현재 지원준비중입니다.

* **기타**

  - 현재 시뮬레이터는 지원하지 않습니다.
  - Bitcode를 지원하지 않으므로 Build Setting - Build Option - Enable Bitcode에서 값을 `NO`로 설정해주세요.


## 사용법

1. **Header File Import** 

  VoiceLoco Call SDK를 사용하기 위해서는 관련 헤더파일을 추가해야합니다. 
  ```
  #import <VLVoice/VLVoice.h>
  ```

2. **Access Token 요청 및 미디어 서버 등록**

  * Access Token 요청

  VoiceLoco Call SDK를 사용하기 위해서는 Access Token을 VoiceLoco 서버로부터 발급받은 다음 SDK에 등록해줘야합니다.
  이 과정은 App에서 진행할 수 있지만 보안을 위해서 자체 서버를 구성하여 받아오는 것을 추천합니다.

  * SampleApp

  샘플 앱에서는 `[getAccessToken:]` 함수를 호출하여 테스트용 Access Token을 받아옵니다.


3. **Access Token 및 푸시 등록**

  샘플 앱에서는 `Device Token`을 먼저 받고, 그 다음 `VoiceLoco 서버`에 `Access Token`을 요청하여 이 두개의 token을 모두 성공적으로 가져오면 미디어 서버에 등록 요청을 합니다. 
  등록요청할때는 `[VLVoice registerWithUserId:AccessToken:deviceToken:completion:]` 를 호출하여 `사용자의 ID`와 `Access token`과 `Device token`를 등록합니다.


4. **전화걸기**
  * 상대방에게 전화를 걸기위해서는 VoiceLoco 서버에 등록된 자신의 아이디와 전화를 받을 상대방의 아이디를 알아야 합니다.
  이 부분은 VoiceLoco Rest API를 참고하여 진행해주시면 됩니다.
  * 전화는 SDK의 `[VLVoice makeACallWithParams:uuid:delegate:]`함수를 호출하면 전화 요청이 상대방에게 가게 됩니다.  
  그리고 파라메터 중 param은 아래와 같은 구조를 따라야 합니다.
  ```
  { 
    @"caller" : @"전화를 거는 자신의 id", 
    @"callee" : @"전화를 받을 상대방의 id" 
  }
  ```

  전화가 걸리면 파라메터로 넣어준 delegate 함수들이 호출되면서 진행이 됩니다.

  * 샘플앱에서는 CallKit을 통해 이벤트들을 처리 한 후 전화가 시작되는 `[provider:performStartCallAction:]` 함수 내에서 SDK의 발신전화 함수를 호출합니다.


5. **전화받기**

  > iOS에서 전화를 받기 위해서는 사전에 VoiceLoco API 센터에 Voip 인증서를 등록해주어야 가능합니다.
  > 일반 Push 인증서가 아닌 Voip 푸시 인증서여야 합니다.

  * 전화를 받기 위해서는 먼저 푸시를 받을 수 있게 해당 사용자를 미디어 서버에 알려주어야 합니다.
    * 사용자를 등록하는 과정은 **3. Access Token 및 푸시 등록**을 참고하시면 됩니다.

  * 먼저 미디어 서버에서 Apns를 통해 전화가 왔다는 푸시를 앱으로 보내줍니다.
    * 받은 푸시 데이터를 SDK의 `[VLVoice handleNotification:delegate:]` 함수로 보내주면 SDK에서 푸시 데이터를 파싱하여 연결된 delegate 를 통해 해당 함수들을 호출합니다. 
    * SDK가 연결된 delegate의 `[callInviteReceived:]` 함수를 호출하면서 `VLCallInvite` 를 전달해줍니다.
    * 전달받은 `VLCallInvite`의 `[VLCallInvite acceptWithDelegate:]` 함수를 호출하면 전화가 연결됩니다.

  * 샘플앱
    * 앱 처음 실행시 `Caller Account TextField`에 값이 존재하면 `Device Token`을 받는 `[pushRegistry:registry didUpdatePushCredentials:credentials forType:type]` 함수에서 `Access Token`을 요청하면서 현재 사용자를 미디어 서버에 등록합니다.
    * SDK가 연결된 delegate의 `[callInviteReceived:]` 를 호출하여 CallKit에 전화가 왔음을 보고합니다.
    * CallKit 화면에서 전화 수락을 선택하면 `[provider:performAnswerCallAction:]` 함수가 호출됩니다.
    * 위의 함수에서 전화가 연결되었다는 SDK의 `[VLCallInvite acceptWithDelegate:]` 함수를 호출하면서 실제로 전화가 연결됩니다.
