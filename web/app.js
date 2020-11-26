function alertMessage(text) {
    alert(text)
}

function openFileDialog() {
    var input = document.createElement('input');
    input.type = 'file';
    input.onchange = e => {
        // getting a hold of the file reference
        var file = e.target.files[0];

        // setting up the reader
        var reader = new FileReader();
        reader.readAsText(file,'UTF-8');

        // here we tell the reader what to do when it's done reading...
        reader.onload = readerEvent => {
            //TBD: DD implement reading content
            console.log('WE LOADED FILE');
        }
    }
    input.click();
}