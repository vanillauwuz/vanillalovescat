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
    } else {
        if (pos === 1) {
            document.title = text[0];
            reverseMode = false;
        } else {
            document.title = document.title.slice(0, -1);
            pos--;
        }
    }
}

window.onload = () => {
    document.title = text[0];
    setInterval(loop, 300);
};

function overlayblock(): void {
    (document.getElementById("overlay") as HTMLElement).style.display = "none";
}

async function Copy(text: string): Promise<void> {
    try {
        await navigator.clipboard.writeText(text);
        console.log('Text copied to clipboard');
    } catch (err) {
        console.error('Failed to copy text: ', err);
    }
}

var notification = document.querySelector(".notification") as HTMLElement 

async function getNotified(message: string): Promise<void> {
    if (!notification) {
        console.error('Notification element not found');
        return;
    }

    var messageElement = notification.querySelector('.message') as HTMLElement
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
        if (
            notification.classList.contains("active") &&
            !notification.classList.contains("hidden")
        ) {
            notification.classList.toggle("active");
            notification.classList.toggle("hidden");
        } else {
            clearTimeout(timeout);
        }
    }, 2000);
}