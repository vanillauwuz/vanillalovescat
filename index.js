var flip = false;
var curStr = "v";
var pos = 0;
var increment = 1;

var textL = "vanillalovecat";
var textR = "vanillalovecat";

function loop() {
    var target = flip ? textR : textL;

    if (pos >= target.length || pos < 0) {
        increment = -increment;
        flip = !flip;
    }

    curStr = target.substring(0, pos);
    pos += increment;

    document.getElementsByTagName("title")[0].innerHTML = curStr || "v";
}

setInterval(loop, 300);

const button = document.querySelector("button"),
    notifications = document.querySelector(".notifications")
closeIcon = document.querySelector(".close"),
    progress = document.querySelector(".progress");
let timer1, timer2;
button.addEventListener("click", () => {
    notifications.classList.add("active");
    progress.classList.add("active");
    timer1 = setTimeout(() => {
        notifications.classList.remove("active");
    }, 5000); //1s = 1000 milliseconds
    timer2 = setTimeout(() => {
        progress.classList.remove("active");
    }, 5300);
});

closeIcon.addEventListener("click", () => {
    notifications.classList.remove("active");

    setTimeout(() => {
        progress.classList.remove("active");
    }, 300);
    clearTimeout(timer1);
    clearTimeout(timer2);
});

function DiscordCopy() {
    navigator.clipboard.writeText("vanmiscat");
}

var audio = document.getElementById('background-audio');
var playButton = document.getElementById('play-button');

playButton.addEventListener('click', function() {
  if (audio.paused) {
    audio.play();
    playButton.className = 'fa-solid fa-volume-high';
  } else {
    audio.pause();
    playButton.className = 'fa-solid fa-volume-xmark';
  }
});

audio.addEventListener('ended', function() {
    audio.currentTime = 0;
    audio.play();
});

document.addEventListener("keydown", function(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === "s") {
        window.location.href = "https://www.pornhub.org";
        event.preventDefault();
    }
});
