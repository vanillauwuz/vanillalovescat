"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var text = "vanillalovescat.space";
var pos = 1;
var reverseMode = false;
function loop() {
    if (!reverseMode) {
        document.title += text[pos];
        pos++;
        if (pos === text.length) {
            reverseMode = true;
            pos = text.length - 1;
        }
    }
    else {
        if (pos === 1) {
            document.title = text[0];
            reverseMode = false;
        }
        else {
            document.title = document.title.slice(0, -1);
            pos--;
        }
    }
}
window.onload = () => {
    document.title = text[0];
    setInterval(loop, 300);

    document.addEventListener('click', () => {
        document.getElementById("bg-audio").play();
    });
};
function overlayblock() {
    document.getElementById("overlay").style.display = "none";
}
function Copy(text) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            yield navigator.clipboard.writeText(text);
            console.log('Text copied to clipboard');
        }
        catch (err) {
            console.error('Failed to copy text: ', err);
        }
    });
}
var notification = document.querySelector(".notification");
function getNotified(message) {
    return __awaiter(this, void 0, void 0, function* () {
        if (!notification) {
            console.error('Notification element not found');
            return;
        }
        var messageElement = notification.querySelector('.message');
        if (!messageElement) {
            console.error('Message element not found');
            return;
        }
        messageElement.textContent = message;
        if (notification.classList.contains("hidden")) {
            notification.classList.toggle("hidden");
        }
        notification.classList.toggle("active");
        var timeout = setTimeout(() => {
            if (notification.classList.contains("active") &&
                !notification.classList.contains("hidden")) {
                notification.classList.toggle("active");
                notification.classList.toggle("hidden");
            }
            else {
                clearTimeout(timeout);
            }
        }, 2000);
    });
}
