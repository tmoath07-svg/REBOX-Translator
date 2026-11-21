import Foundation

enum REBOXTVHTML {
    static let page = #"""
<!doctype html>
<html lang="ar" dir="rtl"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>REBOX Translator — LG</title>
<style>
html,body{height:100%;width:100%;margin:0;overflow:hidden;background:#070a10;color:white;font-family:Arial,Tahoma,sans-serif}
video{position:absolute;inset:0;width:100%;height:100%;object-fit:fill;display:none}
#caption{position:absolute;top:77%;left:7%;width:86%;box-sizing:border-box;text-align:center;
white-space:pre-wrap;font-size:27pt;font-weight:bold;line-height:1.5;text-shadow:0 2px 5px #000;
background:rgba(0,0,0,.76);border-radius:12px;padding:7px 20px;display:none}
#panel{position:absolute;right:4%;top:5%;padding:23px;background:#111b2af2;
border:2px solid #6bdfff;border-radius:16px;width:570px;max-width:85vw;box-sizing:border-box}
h1{color:#68dfff}p{font-size:18px;line-height:1.4;color:#dae4ef}
button{padding:12px 16px;margin:4px;background:#344556;border:0;border-radius:10px;color:#fff;font-size:20px}
button.active,button:focus{background:#62d9fc;color:#09141e}
</style></head><body>
<video id="hdmi" autoplay muted playsinline></video>
<div id="caption"></div>
<div id="panel">
<h1>REBOX Translator</h1>
<p>استقبال الترجمة من Xbox عبر الآيفون. اختيار HDMI هنا تجريبي: بعض متصفحات LG لا تدعم عرض مدخل HDMI داخل الصفحة.</p>
<div id="inputs">
<button data-port="0" class="active">الترجمة فقط</button>
<button data-port="1">HDMI 1</button>
<button data-port="2">HDMI 2</button>
<button data-port="3">HDMI 3</button>
<button data-port="4">HDMI 4</button>
</div>
<button id="hide">إخفاء القائمة</button>
<button id="full">ملء الشاشة</button>
<p id="status">بانتظار الجوال...</p>
<p>اضغط OK بالريموت لإظهار القائمة من جديد.</p>
</div>
<script>
(function(){
var v=document.getElementById('hdmi'),c=document.getElementById('caption');
var p=document.getElementById('panel'),status=document.getElementById('status');
function choose(n){
 for(var b of document.querySelectorAll('[data-port]'))b.className=(Number(b.getAttribute('data-port'))===n?'active':'');
 if(!n){v.pause();v.innerHTML='';v.removeAttribute('src');v.load();v.style.display='none';return;}
 v.innerHTML='';var s=document.createElement('source');s.type='service/webos-external';
 s.src='ext://hdmi:'+n;v.appendChild(s);v.style.display='block';v.load();
 var promise=v.play();if(promise&&promise.catch)promise.catch(function(){status.textContent='متصفح LG لا يدعم عرض HDMI المضمن';});
}
document.getElementById('inputs').onclick=function(e){if(e.target.hasAttribute('data-port'))choose(Number(e.target.getAttribute('data-port')));};
document.getElementById('hide').onclick=function(){p.style.display='none';};
document.getElementById('full').onclick=function(){var f=document.documentElement.requestFullscreen;if(f){var q=f.call(document.documentElement);if(q&&q.catch)q.catch(function(){});}else status.textContent='ملء الشاشة غير مدعوم';};
document.addEventListener('keydown',function(e){if((e.key==='Enter'||e.keyCode===13)&&p.style.display==='none')p.style.display='block';});
function poll(){
 var x=new XMLHttpRequest();x.open('GET','/state?ts='+Date.now(),true);x.timeout=2700;
 x.onload=function(){if(x.status!==200){status.textContent='HTTP '+x.status;return;}
 try{var d=JSON.parse(x.responseText);c.textContent=String(d.subtitle||'');
 c.style.display=c.textContent?'block':'none';status.textContent='REBOX متصل';}
 catch(err){status.textContent='بيانات الترجمة غير صالحة';}};
 x.onerror=x.ontimeout=function(){status.textContent='انقطع الاتصال بالآيفون';c.style.display='none';};
 x.send();
}
poll();setInterval(poll,900);
})();
</script></body></html>
"""#
}
