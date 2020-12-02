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

    // Create proper image instance
    createImageInstance(file);
}

function createImageInstance(srcImageFile) {
    console.log('url createObjectUrl');
    var url = URL.createObjectURL(srcImageFile);
    var img = new Image();
    img.onload = function() {
        console.log('call crop image');
        cropImage(img);
    }
    console.log('img.src = url');
    img.src = url;
}

function cropImage(image) {
    // Crop Image
    console.log('create canvas');
    var canvas = document.createElement('canvas');
    console.log('create ctx');
    var ctx = canvas.getContext('2d');
    console.log('draw image');
    //TBD: check if is 1024x1024
    ctx.drawImage(image, 0, 156, 1024, 1024, 0, 0, 1024, 1024);
    console.log('canvas to blob');
    canvas.toBlob(croppedImage => {
        // Pass cropped image for decoding
        console.log('pass cropped image to reader');
        readImageFile(croppedImage)
    }, File.type);
}

function readImageFile(imageFile) {
    // setting up the reader
    var reader = new FileReader();
    reader.readAsDataURL(imageFile);

    // here we tell the reader what to do when it's done reading...
    reader.onload = readerEvent => {
        onReaderFileLoad(readerEvent)
    }
        //TBD: TMP debug image
//    reader.onload = function(e) {
//        var image = document.createElement("img");
//        // the result image data
//        image.src = e.target.result;
//        document.body.appendChild(image);
//    }
}

function onReaderFileLoad(readerEvent) {
    var content = readerEvent.target.result;

    // set the callback that receives the decoded content as the tasks is async
    qrcode.callback = function(qrCodeValue) {
    //TBD: DD - return the value to flutter
        alert(qrCodeValue);
    };

    // Start decoding the base64 string
    qrcode.decode(content);
}