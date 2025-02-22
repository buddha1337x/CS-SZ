window.addEventListener('message', function(event) {
    const data = event.data;
    const overlay = document.getElementById("safezoneOverlay");
    if (data.action === "show") {
        overlay.classList.remove("hidden");
    } else if (data.action === "hide") {
        overlay.classList.add("hidden");
    }
});
