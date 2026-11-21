# REBOX Translator acceptance criteria

A passing GitHub build is not proof that automatic translation works on hardware.

| Test | Success criterion |
| --- | --- |
| Microsoft sign in | Xbox account authenticates successfully |
| Xbox streaming | Native video frames appear and update inside REBOX |
| OCR | Two stable reads of actual visible English subtitles are recognized |
| Translation | Downloaded English/Arabic Apple models translate a real line |
| LAN | LG opens the displayed `/tv` link on the same Wi-Fi |
| HTTP | `/state?nonce=` returns 200 and shows changing captions |
| No camera | App never asks for camera permission |
| LG HDMI composition | Xbox live picture and translation *simultaneously* visible on the particular LG model |
| Mobile signing | Unsigned IPA can be installed with user's valid iOS signing arrangement |

The LG **system browser** might not support embedding HDMI. The LG IPK is experimental, not guaranteed to overlay the external HDMI plane. Do not claim full functionality until real-device checks pass.

No paid APIs or subscriptions are built into the REBOX translator source. Apple language model downloads may be required; Microsoft login and a compatible Xbox stream are prerequisites.
