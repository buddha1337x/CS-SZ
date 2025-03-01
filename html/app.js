window.addEventListener('message', function(event) {
    const data = event.data;
    const safezoneOverlay = document.getElementById("safezoneOverlay");
    const creationModeOverlay = document.getElementById("creationModeOverlay");

    if (data.action === "show") {
        safezoneOverlay.classList.remove("hidden");
    } else if (data.action === "hide") {
        safezoneOverlay.classList.add("hidden");
    } else if (data.action === "showCreationMode") {
        creationModeOverlay.querySelector(".message").innerHTML = data.text;
        creationModeOverlay.classList.remove("hidden");
    } else if (data.action === "hideCreationMode") {
        creationModeOverlay.classList.add("hidden");
    } else if (data.action === "updateCreationModeText") {
        // Update the text without toggling visibility.
        creationModeOverlay.querySelector(".message").innerHTML = data.text;
    }
});
