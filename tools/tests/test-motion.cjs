// Integration check with the delivered, unversioned media package.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const media=process.env.HOLODECK_MEDIA_DIR;
if(!media)throw Error('Set HOLODECK_MEDIA_DIR to the delivered holodeck-motion directory.');
const compass=path.resolve(__dirname,'../../compass');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.HOLODECK_BROWSER_CHANNEL?{channel:process.env.HOLODECK_BROWSER_CHANNEL}:{})});
 try{
 const page=await browser.newPage({viewport:{width:1440,height:950}});let failVideo=false;const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',async route=>{
  const u=new URL(route.request().url());
  if(u.pathname==='/')return route.fulfill({contentType:'text/html',body:'<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><link rel="stylesheet" href="/holodeck-engine/experience.css"><div class="jgr jgr-experience" open><div id="host" style="height:100vh"></div></div><script type="module">import {mountHolodeck} from "/holodeck-engine/experience.js"; window.room=mountHolodeck(document.querySelector("#host"));</script>'});
  if(u.pathname.endsWith('/motion-manifest.json'))return route.fulfill({json:JSON.parse(fs.readFileSync(path.join(media,'motion-manifest.json'),'utf8'))});
  if(u.pathname.includes('/motion/')){
   if(failVideo&&u.pathname.endsWith('.mp4'))return route.fulfill({status:404,body:''});
   const file=path.join(media,path.basename(u.pathname));
   return route.fulfill({body:fs.readFileSync(file),contentType:file.endsWith('.mp4')?'video/mp4':'image/png'});
  }
  if(u.pathname.endsWith('/manifest.json'))return route.fulfill({json:{assets:{}}});
  if(/\.(png|webp)$/.test(u.pathname))return route.fulfill({contentType:'image/svg+xml',body:'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900"><rect width="1600" height="900" fill="#132433"/></svg>'});
  const file=path.resolve(compass,'.'+u.pathname);
  if(!file.startsWith(compass+path.sep)||!fs.existsSync(file))return route.fulfill({status:404,body:''});
  return route.fulfill({body:fs.readFileSync(file),contentType:file.endsWith('.css')?'text/css':'application/javascript'});
 });
 const open=async()=>{await page.goto('https://holodeck.test/');await page.waitForFunction(()=>window.room?.getPlaybackState().motionReady);};
 const enter=async()=>{await page.getByRole('button',{name:'In Ruhe eintreten',exact:true}).click();};
 const sit=async()=>{await page.getByRole('button',{name:'Auf die Enterprise',exact:false}).click();await page.locator('[data-phase=conversation]').waitFor();};
 await open();await enter();await page.locator('[data-phase=entrance]').waitFor();
 await page.waitForFunction(()=>document.querySelector('video')?.currentTime>.2);
 assert(await page.locator('video').evaluate(v=>v.muted&&!v.loop&&v.videoWidth===1280));
 await page.locator('[data-phase=seating]').waitFor();await sit();
 await page.waitForFunction(()=>document.querySelector('.holo-john video')?.currentTime>.3);
 const v=page.locator('.holo-john video');assert(await v.evaluate(v=>v.muted&&!v.loop&&v.videoWidth===736));
 await page.waitForFunction(()=>document.querySelector('.holo-john video')?.ended);
 await page.evaluate(()=>room.setListening(true));
 await page.waitForFunction(()=>{const v=document.querySelector('.holo-john video');return v&&!v.ended&&!v.paused&&v.currentTime>.1});
 await page.evaluate(()=>room.setSpeaker('john'));assert(await v.evaluate(v=>v.paused));
 await page.evaluate(()=>{room.setSpeaker(null);room.setListening(false);room.setListening(true)});
 await page.waitForFunction(()=>!document.querySelector('.holo-john video').paused);
 await page.getByRole('button',{name:'Unterbrechen',exact:true}).click();assert(await v.evaluate(v=>v.paused));
 await page.setViewportSize({width:390,height:844});
 assert(await page.locator('.holo-experience').evaluate(n=>n.scrollWidth<=n.clientWidth));
 if(process.env.HOLODECK_SCREENSHOT)await page.screenshot({path:process.env.HOLODECK_SCREENSHOT});
 await page.evaluate(()=>room.pause());assert(await v.evaluate(v=>v.paused));
 await page.evaluate(()=>room.resume());assert(await v.evaluate(v=>v.paused),'No unexpected restart on resume');
 await page.getByRole('button',{name:'Anderer Platz',exact:true}).click();assert.equal(await page.locator('.holo-john').count(),0);
 await page.evaluate(()=>room.dispose());assert.equal(await page.locator('video').count(),0);
 await page.emulateMedia({reducedMotion:'reduce'});await open();await enter();await sit();
 assert.equal(await page.locator('video').count(),0,'Reduced motion shows poster only');
 await page.emulateMedia({reducedMotion:'no-preference'});failVideo=true;await open();await enter();
 await page.locator('[data-phase=seating]').waitFor();await sit();
 await page.waitForFunction(()=>{const v=document.querySelector('.holo-john video');return v?.hidden});
 assert.equal(await page.locator('.holo-john').getAttribute('data-media'),'poster');
 assert.deepEqual(errors,[]);console.log('PASS: actual clips decode and play; entry finishes; listening replays once; speaking/interrupt/pause stop; mobile fits; reduced motion and missing-video fallback; dispose.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
