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

    // setting up the reader
    var reader = new FileReader();
    reader.readAsDataURL(file);

    // here we tell the reader what to do when it's done reading...
    reader.onload = readerEvent => {
        onFileLoad(readerEvent)
    }
}

function onFileLoad(readerEvent) {
    var content = readerEvent.target.result;

    // set the callback that receives the decoded content as the tasks is async
    qrcode.callback = function(qrCodeValue) {
    //TBD: DD - return the value to flutter
        alert(qrCodeValue);
    };

    // Start decoding the base64 string
    qrcode.decode(content);
}