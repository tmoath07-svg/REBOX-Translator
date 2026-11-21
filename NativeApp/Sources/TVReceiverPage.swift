import Foundation

enum TVReceiverPage {
    static let html = #"""
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>GAME SUB — LG Receiver</title>
  <style>
    html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#060912;color:#fff;font-family:Arial,Tahoma,sans-serif}
    video{position:absolute;width:100%;height:100%;object-fit:fill;display:none}
    #caption{position:absolute;top:76%;left:6%;width:88%;box-sizing:border-box;text-align:center;
      font-weight:900;font-size:34px;line-height:1.6;padding:14px 24px;border-radius:14px;
      background:rgba(0,0,0,.74);text-shadow:1px 2px 5px #000;display:none}
    #menu{position:absolute;top:5%;right:4%;width:550px;max-width:88%;padding:22px;
      background:#0d1829f5;border:2px solid #72daff;border-radius:18px;box-sizing:border-box}
    h1{margin-top:0;color:#72daff}p{color:#d6e0ee;line-height:1.5}
    button{font-size:18px;background:#2a3d56;color:#fff;border:0;padding:11px 16px;
      margin:5px;border-radius:10px}
    button:focus,button.active{background:#60d5f5;color:#062033}
    #state{font-size:16px;color:#fbbf24}
  </style>
</head>
<body>
  <video id="hdmi" muted autoplay playsinline></video>
  <div id="caption" aria-live="polite"></div>
  <div id="menu">
    <h1>GAME SUB · الترجمة</h1>
    <p>وصلنا بجوالك؟ الترجمة تجي من بث Xbox داخل تطبيق GAME SUB، بدون كاميرا.</p>
    <p>عرض HDMI داخل متصفح LG تجريبي، وقد لا يدعمه موديل تلفزيونك. إذا الشاشة سوداء اختر «ترجمة فقط».</p>
    <div id="inputs">
      <button class="active" data-port="0">ترجمة فقط</button>
      <button data-port="1">HDMI 1</button>
      <button data-port="2">HDMI 2</button>
      <button data-port="3">HDMI 3</button>
      <button data-port="4">HDMI 4</button>
    </div>
    <div>
      <button id="hide">إخفاء الإعدادات</button>
      <button id="full">ملء الشاشة</button>
    </div>
    <p id="state">بانتظار اتصال التطبيق...</p>
    <p>اضغط OK بالريموت لإظهار القائمة مجددًا.</p>
  </div>
<script>
(function(){
 var movie=document.getElementById('hdmi');
 var caption=document.getElementById('caption');
 var menu=document.getElementById('menu');
 var state=document.getElementById('state');
 var selector=document.getElementById('inputs');
 function choose(number) {
   var buttons=selector.querySelectorAll('button');
   for (var i=0;i<buttons.length;i++) {
      var button=buttons[i];
      button.className=Number(button.getAttribute('data-port'))===number?'active':'';
   }
   movie.pause();movie.innerHTML='';
   movie.removeAttribute('src');
   movie.style.display='none';
   if(number===0) return;
   var source=document.createElement('source');
   source.type='service/webos-external';
   source.src='ext://hdmi:'+number;
   movie.appendChild(source);
   movie.style.display='block';
   movie.load();
   try {
     var play=movie.play();
     if(play && play.catch) play.catch(function(){state.textContent='متصفح LG لا يستطيع تشغيل HDMI هنا';});
   } catch(error) { state.textContent='عرض HDMI غير مدعوم'; }
 }
 selector.onclick=function(event) {
   var target=event.target;
   if(target.hasAttribute('data-port')) choose(Number(target.getAttribute('data-port')));
 };
 document.getElementById('hide').onclick=function(){menu.style.display='none';};
 document.getElementById('full').onclick=function(){
   var fn=document.documentElement.requestFullscreen || document.documentElement.webkitRequestFullscreen;
   if(fn){try{fn.call(document.documentElement);}catch(error){}}else{state.textContent='ملء الشاشة غير متاح';}
 };
 document.onkeydown=function(event){
   if((event.keyCode===13 || event.key==='Enter') && menu.style.display==='none') menu.style.display='block';
 };
 function poll() {
   var x=new XMLHttpRequest();
   x.open('GET','/state?t='+Date.now(),true);
   x.timeout=2800;
   x.onload=function(){
     if(x.status!==200) {state.textContent='HTTP '+x.status;return;}
     try {
       var info=JSON.parse(x.responseText);
       caption.textContent=String(info.subtitle || '');
       caption.style.display=caption.textContent?'block':'none';
       state.textContent='GAME SUB متصل';
       state.style.color='#4ade80';
     } catch(error) {state.textContent='بيانات الترجمة غير صحيحة';}
   };
   x.onerror=x.ontimeout=function(){
     state.textContent='انقطع الاتصال بالجوال';
     state.style.color='#fbbf24';
   };
   x.send();
 }
 poll();setInterval(poll,1100);
})();
</script>
</body>
</html>
"""#
}
