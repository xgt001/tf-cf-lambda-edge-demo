var app = new Spa();

var aboutPage = document.getElementById('go-about'),
    aboutPage2 = document.getElementById('go-about2');

document.getElementById('go-back').onclick = function(){
    app.router.back();
};

document.getElementById('go-back2').onclick = function(){
    app.router.back();
};

app.router.before('about', function(page){
    console.log(page);
});

app.router.after('about', function(page){
    console.log(page);
});

app.router.before('services', function(page){
    console.log(page);
});
app.router.after('services', function(page){
    console.log(page);
});