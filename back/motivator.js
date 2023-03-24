const fs = require('fs');
var admin = require("firebase-admin");  
var serviceAccount = require(__dirname+"/motivator-e5bab-2691bbd72818.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

if (process.argv[2] == 'addQuotes') {
  addQuotes();
  return;
}

let arQuotes = [];

sendQuoteToUsers();

async function sendQuoteToUsers(){
  let now = new Date();
  let nowHM = now.getHours()*60 + now.getMinutes();
  console.log('sendQuoteToUsers now', now, 'nowHM', nowHM);
  if (arQuotes.length == 0) {
    await getQuotes();
  }
  let quote = arQuotes[Math.floor(Math.random() * arQuotes.length)];
  console.log('got quote to send', quote);
  fbSnapshot = await db.collection('users').where("isPushesWanted", '==', true).get();
  fbSnapshot.forEach((doc) => {
      let user = doc.data();
      user.id = doc.id;
      console.log('got user', user);
      let wantedDT = new Date(user.dt._seconds*1000);
      let wantedHM = wantedDT.getHours()*60 + wantedDT.getMinutes();
      console.log('wantedDT', wantedDT, 'wantedHM', wantedHM);
      if (wantedHM >= nowHM && wantedHM < (nowHM+5)) {
        console.log('need to send.');
        sendFCM(user.fcm, 'Once '+quote.author+' said:', quote.quote, {"quote": quote.quote, "author": quote.author});
      } else {
        console.log('skip. Not in time.');
      }
  });
  setTimeout(sendQuoteToUsers, 5*60*1000);
}

async function getQuotes(){
  console.log('getting quotes', (new Date()));
  let arRes = [];
  fbSnapshot = await db.collection('quotes').get();
  fbSnapshot.forEach((doc) => {
      let data = doc.data();
      data.id = doc.id;
      arRes.push(data);
  });  
  console.log('got quotes from fb:', arRes.length);
  if (arRes.length > 0) {
    arQuotes = arRes;
    console.log('fill arQuotes');
  }
  setTimeout(getQuotes, 24*60*60*1000);
}

async function addQuotes(){
  console.log('addQuotes');
  let quotes = ''+fs.readFileSync('dale2.txt');
  let delim = RegExp("\" [—–―-]", "i"); //— – ―
  let arQuotes = quotes.split('\n');
  console.log('got length', arQuotes.length);
  for (let idx=0; idx<arQuotes.length; idx++) {
    let quote = arQuotes[idx];
    if (quote.length < 10) {
      continue;
    }
    let author = quote.split(delim)[1].trim();
    let body = quote.split(delim)[0].trim();

    if (!author) {
      console.log('no author for', quote);
    }

    await db.collection('quotes').add({author, quote: body});
    console.log('author', author, 'body', body);
  }
  console.log('finish addQuotes');
}

async function sendFCM(fcmToken, title, body, data){
	console.log('sending FCM with', title, body, fcmToken);
  if (data == undefined) {
    data = {};
  }
	var fcmPayload = { 
    notification: {title, body}, 
    data
  };

	console.log('sending fcmPayload', fcmPayload);
	
	var fcmOptions = {
	  priority: "high",
	  timeToLive: 60 * 60 *24,
	};

	admin.messaging().sendToDevice(fcmToken, fcmPayload, fcmOptions)
	.then(function(response) {
		console.log("Successfully sent FCM message:", response);
	}).catch(function(error) {
		console.log("Error sending FCM message:", error);
	});	
}