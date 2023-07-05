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