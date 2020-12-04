async function readQrCodeImage() {
    //TBD: make it with promise
//    var qrValue;
//    var input = document.createElement('input');
//    input.type = 'file';
//    input.onchange = event => {
//        scanImageFile(event);
//    }
//    input.click();

    console.log('start promise');
    let qrCode = await getQrCodeValue();
    console.log('awaited qrCode')
    console.log(qrCode)
    return qrCode;
}

function getQrCodeValue() {
    return new Promise((resolve, reject) => {
        resolve('qrCodeValuee');
    });
}

function onFileChange(event) {
    scanImageFile(event);
}

async function scanImageFile(event) {
    // getting a hold of the file reference
    var imageFile = event.target.files[0];

    // Scan the file
    QrScanner.WORKER_PATH = 'qr/qr-scanner-worker.min.js';
    var result;
    try {
        result = await QrScanner.scanImage(imageFile);
    }
    catch(err) {
        console.log('Failed to scan qr code image. Reason:');
        console.log(err);
    }
    return result;
}