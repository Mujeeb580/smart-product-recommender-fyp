// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBCgbhGTdczQ-mVpbxARiv_ZWR-ib7AFRI",
  authDomain: "smart-product-recommender-fyp.firebaseapp.com",
  databaseURL: "https://smart-product-recommender-fyp-default-rtdb.firebaseio.com",
  projectId: "smart-product-recommender-fyp",
  storageBucket: "smart-product-recommender-fyp.firebasestorage.app",
  messagingSenderId: "1042809810856",
  appId: "1:1042809810856:web:04135233f87c3328ad379d"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);