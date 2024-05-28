function copyBtn(stringText) {
    navigator.clipboard.writeText(stringText);
}

// var text = "vanillalovescat.space";
// var pos = 1;
// var reverseMode = false;

// function loop() {
//     if (!reverseMode) {
//         document.title += text[pos];
//         pos++;

//         if (pos === text.length) {
//             reverseMode = true;
//             pos = text.length - 1;
//         }
//     } else {
//         if (pos === 1) {
//             document.title = text[0];
//             reverseMode = false;
//         } else {
//             document.title = document.title.slice(0, -1);
//             pos--;
//         }
//     }
// }

// window.onload = () => {
//     document.title = text[0];
//     setInterval(loop, 300);

//     document.addEventListener('click', () => {
//         (document.getElementById("bg-audio").HTMLAudioElement).play();
//     });
// };

// function overlayblock() {
//     (document.getElementById("overlay").HTMLElement).style.display = "none";
// }

// var notification = document.querySelector(".notification") as HTMLElement 

// async function getNotified(message: string): Promise<void> {
//     if (!notification) {
//         console.error('Notification element not found');
//         return;
//     }

//     var messageElement = notification.querySelector('.message') as HTMLElement
//     if (!messageElement) {
//         console.error('Message element not found');
//         return;
//     }

//     messageElement.textContent = message;

//     if (notification.classList.contains("hidden")) {
//         notification.classList.toggle("hidden");
//     }
//     notification.classList.toggle("active");

//     var timeout = setTimeout(() => {
//         if (
//             notification.classList.contains("active") &&
//             !notification.classList.contains("hidden")
//         ) {
//             notification.classList.toggle("active");
//             notification.classList.toggle("hidden");
//         } else {
//             clearTimeout(timeout);
//         }
//     }, 2000);
// }

{/* <div class="font-semibold notification">
              <img src="./assets/image/kuromi.png" alt="" />
              <div class="details">
                <div class="name">vanilla</div>
                <div class="message"></div>
              </div>
          </div>
        </div> */}


        // .notification {
        //     position: fixed;
        //     top: 15px;
        //     left: 50%;
        //     transform: translate(-50%, -200px);
        //     background: rgb(0, 0, 0);
        //     width: fit-content;
        //     height: 54px;
        //     box-sizing: border-box;
        //     padding: 8px;
        //     border-radius: 15mm;
        //     display: flex;
        //     align-items: center;
        //     justify-content: space-between;
        //     overflow: hidden;
        //     box-shadow: rgba(255, 255, 255, 0.1) 0px 0px 30px;
        //     transition: 0.5s ease-in;
        //     max-width: 1000px;
        // }
        
        // .notification img {
        //     width: 32px;
        //     height: 32px;
        //     border-radius: 50%;
        //     border: 4px solid rgb(80, 80, 80);
        //     transition: 0.35s ease-in;
        // }
        
        // .details {
        //     display: flex;
        //     align-items: flex-start;
        //     justify-content: center;
        //     flex-direction: column;
        //     margin: 0 15px;
        //     padding: 1px;
        //     white-space: nowrap;
        // }
        
        // .name {
        //     font-size: 12px;
        //     color: rgba(255, 255, 255, 0.6);
        // }
        
        // .message {
        //     font-size: 14px;
        //     color: white;
        // }
        
        // .notify {
        //     background: rgb(226, 230, 233);
        //     width: 50px;
        //     height: 50px;
        //     border-radius: 50%;
        //     border: none;
        //     outline: none;
        //     cursor: pointer;
        // }
        
        // .notify span {
        //     font-size: 30px;
        // }
        
        // .notification.hidden {
        //     animation: closeNote 1s ease-in-out;
        //     transform: translate(-50%, -200px);
        //     max-width: 54px;
        //     padding: 0;
        // }
        
        // .notification.hidden img {
        //     width: 38px;
        //     height: 38px;
        //     border: 8px solid rgb(80, 80, 80);
        // }
        
        // @keyframes closeNote {
        //     0% {
        //         transform: translate(-50%, 0);
        //         max-width: 1000px;
        //         padding: 8px;
        //     }
        
        //     65% {
        //         transform: translate(-50%, 0);
        //         max-width: 54px;
        //         padding: 0px;
        //     }
        
        //     100% {
        //         transform: translate(-50%, -200px);
        //         max-width: 54px;
        //         padding: 0;
        //     }
        // }
        
        // .notification.active {
        //     animation: showNote 1s ease-in-out;
        //     max-width: 1000px;
        //     transform: translate(-50%, 0);
        //     padding: 8px;
        // }
        
        // .notification.active img {
        //     animation: resize 1s ease-in-out;
        //     width: 32px;
        //     height: 32px;
        //     border: 4px solid rgb(80, 80, 80);
        // }
        
        // @keyframes showNote {
        //     0% {
        //         transform: translate(-50%, -200px);
        //         max-width: 54px;
        //         padding: 0;
        //     }
        
        //     35% {
        //         transform: translate(-50%, 0px);
        //         max-width: 54px;
        //         padding: 0;
        //     }
        
        //     100% {
        //         transform: translate(-50%, 0px);
        //         max-width: 1000px;
        //         padding: 8px;
        //     }
        // }
        
        // @keyframes resize {
        
        //     0%,
        //     40% {
        //         width: 38px;
        //         height: 38px;
        //         border: 8px solid rgb(80, 80, 80);
        //     }
        
        //     100% {
        //         width: 32px;
        //         height: 32px;
        //         border: 4px solid rgb(80, 80, 80);
        //     }
        // }