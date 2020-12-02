function openFileDialog() {
    var input = document.createElement('input');
    input.type = 'file';
    input.onchange = event => {
        onFileSelected(event);
    }
    input.click();
}

function onFileSelected(event) {
    // getting a hold of the file reference
    var file = event.target.files[0];

    // Scan Image file
    scanImageFile(file);
}

function scanImageFile(imageFile) {
    QrScanner.WORKER_PATH = 'qr/qr-scanner-worker.min.js';
    QrScanner.scanImage(imageFile)
        .then(result => onImageScan(result))
        .catch(error => onImageScan(error || 'No QR code found.'));
}

function onImageScan(result) {
    alert(result)
}