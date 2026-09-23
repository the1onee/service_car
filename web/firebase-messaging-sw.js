importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC01_6BudF63GLe2myMax7io-OxWzNPcrs',
  authDomain: 'car-services-iraq.firebaseapp.com',
  projectId: 'car-services-iraq',
  storageBucket: 'car-services-iraq.firebasestorage.app',
  messagingSenderId: '500429219707',
  appId: '1:500429219707:web:8b462a2849c3e20acdffde',
  measurementId: 'G-G0C4S627DF',
});

firebase.messaging();
