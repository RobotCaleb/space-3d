// jshint -W097
// jshint undef: true, unused: true
/* globals require,window,document,requestAnimationFrame,dat,location*/

"use strict";

var qs = require("query-string");
var glm = require("gl-matrix");
var saveAs = require("filesaver.js").saveAs;
var JSZip = require("jszip");
var Space3D = require("./space-3d.js");
var Skybox = require("./skybox.js");

var resolution = 512;

window.onload = function () {
  var params = qs.parse(location.hash);

  var ControlsMenu = function () {
    this.seed = params.seed || generateRandomSeed();
    this.randomSeed = function () {
      this.seed = generateRandomSeed();
      renderTextures();
    };
    this.fov = parseInt(params.fov) || 80;
    this.pointStars = params.pointStars === undefined ? true : params.pointStars === "true";
    this.pointStarsPercent = params.pointStarsPercent === undefined ? 50.0 : parseFloat(params.pointStarsPercent);
    this.stars = params.stars === undefined ? true : params.stars === "true";
    this.starsAmount = params.starsAmount === undefined ? 25.0 : parseFloat(params.starsAmount);
    this.sun = params.sun === undefined ? true : params.sun === "true";
    this.sunFalloff = params.sunFalloff === undefined ? 100 : parseFloat(params.sunFalloff);
    this.nebulae = params.nebulae === undefined ? true : params.nebulae === "true";
    this.nebulaOpacity = params.nebulaOpacity === undefined ? 33 : parseInt(params.nebulaOpacity);
    this.noiseScale = params.nebulaOpacity === undefined ? 5 : parseFloat(params.noiseScale);
    this.nebulaBrightness = params.nebulaBrightness === undefined ? 18 : parseInt(params.nebulaBrightness);
    this.resolution = parseInt(params.resolution) || 512;
    this.animationSpeed = params.animationSpeed === undefined ? 1.0 : parseFloat(params.animationSpeed);
    this.url = window.location.href.toString();
    this.saveSkybox = function () {
      const zip = new JSZip();
      for (const name of ["front", "back", "left", "right", "top", "bottom"]) {
        const canvas = document.getElementById(`texture-${name}`);
        const data = canvas.toDataURL().split(",")[1];
        zip.file(`${name}.png`, data, { base64: true });
      }
      if (this.resolution <= 2048) {
        const cubemapData = this._saveCubemap().split(",")[1];
        zip.file('cubemap.png', cubemapData, { base64: true });
      }
      zip.generateAsync({ type: "blob" }).then(blob => {
        saveAs(blob, "skybox.zip");
      });
    };
    this._saveCubemap = function () {
      const cubemapCanvas = document.getElementById('texture-cubemap');
      const left = document.getElementById('texture-left');
      const top = document.getElementById('texture-top');
      const front = document.getElementById('texture-front');
      const bottom = document.getElementById('texture-bottom');
      const right = document.getElementById('texture-right');
      const back = document.getElementById('texture-back');

      // set size of canvas depending on resolution
      var context = cubemapCanvas.getContext('2d');
      context.canvas.width = this.resolution * 4;
      context.canvas.height = this.resolution * 3;

      // combine images together in the texture-cubemap canvas
      context.drawImage(left, 0, this.resolution);
      context.drawImage(top, this.resolution, 0);
      context.drawImage(front, this.resolution, this.resolution);
      context.drawImage(bottom, this.resolution, this.resolution * 2);
      context.drawImage(right, this.resolution * 2, this.resolution);
      context.drawImage(back, this.resolution * 3, this.resolution);

      return cubemapCanvas.toDataURL("image/png");
    };
  };

  var menu = new ControlsMenu();
  var gui = new dat.GUI({
    autoPlace: false,
    width: 320
  });
  gui.add(menu, "seed").name("Seed").listen().onFinishChange(renderTextures);
  gui.add(menu, "randomSeed").name("Randomize seed");
  gui.add(menu, "fov", 10, 150, 1).name("Field of view °");
  gui.add(menu, "pointStars").name("Point stars").onFinishChange(renderTextures);
  gui.add(menu, "pointStarsPercent").name("Point stars %").onFinishChange(renderTextures);
  gui.add(menu, "stars").name("Bright stars").onFinishChange(renderTextures);
  gui.add(menu, "starsAmount").name("Bright stars Amount").onFinishChange(renderTextures);
  gui.add(menu, "sun").name("Sun").onFinishChange(renderTextures);
  gui.add(menu, "sunFalloff", 50, 250, 1).name("Sun Falloff").onFinishChange(renderTextures);
  gui.add(menu, "nebulae").name("Nebulae").onFinishChange(renderTextures);
  gui.add(menu, "nebulaOpacity", 0, 100).name("nebulaOpacity").onFinishChange(renderTextures);
  gui.add(menu, "nebulaBrightness", 0, 100).name("nebulaBrightness").onFinishChange(renderTextures);
  gui.add(menu, "noiseScale", 0, 100).name("noiseScale").onFinishChange(renderTextures);
  gui.add(menu, "resolution", [256, 512, 1024, 2048, 4096]).name("Resolution").onFinishChange(renderTextures);
  gui.add(menu, "animationSpeed", 0, 10).name("Animation speed");
  gui.add(menu, "saveSkybox").name("Download skybox");
  gui.add(menu, "url").name("URL").listen();

  document.body.appendChild(gui.domElement);
  gui.domElement.style.position = "fixed";
  gui.domElement.style.left = "16px";
  gui.domElement.style.top = "272px";

  function hideGui() {
    gui.domElement.style.display = "none";
  }

  function showGui() {
    gui.domElement.style.display = "block";
  }

  function hideSplit() {
    document.getElementById("texture-left").style.display = "none";
    document.getElementById("texture-right").style.display = "none";
    document.getElementById("texture-top").style.display = "none";
    document.getElementById("texture-bottom").style.display = "none";
    document.getElementById("texture-front").style.display = "none";
    document.getElementById("texture-back").style.display = "none";
  }

  function showSplit() {
    document.getElementById("texture-left").style.display = "block";
    document.getElementById("texture-right").style.display = "block";
    document.getElementById("texture-top").style.display = "block";
    document.getElementById("texture-bottom").style.display = "block";
    document.getElementById("texture-front").style.display = "block";
    document.getElementById("texture-back").style.display = "block";
  }

  function setUrl() {
    var queryString = qs.stringify({
      seed: menu.seed,
      fov: menu.fov,
      pointStars: menu.pointStars,
      pointStarsPercent: menu.pointStarsPercent,
      stars: menu.stars,
      starsAmount: menu.starsAmount,
      sun: menu.sun,
      sunFalloff: menu.sunFalloff,
      nebulae: menu.nebulae,
      resolution: menu.resolution,
      animationSpeed: menu.animationSpeed,
      nebulaOpacity: menu.nebulaOpacity,
      nebulaBrightness: menu.nebulaBrightness,
      noiseScale: menu.noiseScale
    });

    var url = new URL(window.location.href);
    url.hash = queryString;
    menu.url = url.toString();
  }

  var hideControls = false;

  window.onkeypress = function (e) {
    if (e.charCode == 32) {
      hideControls = !hideControls;
    }
  };

  var renderCanvas = document.getElementById("render-canvas");
  renderCanvas.width = renderCanvas.clientWidth;
  renderCanvas.height = renderCanvas.clientHeight;

  var skybox = new Skybox(renderCanvas);
  var space = new Space3D(resolution);

  function renderTextures() {
    var textures = space.render({
      seed: menu.seed,
      pointStars: menu.pointStars,
      pointStarsPercent: menu.pointStarsPercent / 100.0,
      stars: menu.stars,
      starsAmount: menu.starsAmount,
      sun: menu.sun,
      sunFalloff: menu.sunFalloff,
      nebulae: menu.nebulae,
      resolution: menu.resolution,
      nebulaOpacity: menu.nebulaOpacity / 100.0,
      nebulaBrightness: menu.nebulaBrightness / 100.0,
      noiseScale: 4.0 * ((menu.noiseScale / 100.0) - 0.5)
    });
    skybox.setTextures(textures);
    var canvas = document.getElementById("texture-canvas");
    canvas.width = 4 * menu.resolution;
    canvas.height = 3 * menu.resolution;
    var ctx = canvas.getContext("2d");
    ctx.drawImage(textures.left, menu.resolution * 0, menu.resolution * 1);
    ctx.drawImage(textures.right, menu.resolution * 2, menu.resolution * 1);
    ctx.drawImage(textures.front, menu.resolution * 1, menu.resolution * 1);
    ctx.drawImage(textures.back, menu.resolution * 3, menu.resolution * 1);
    ctx.drawImage(textures.top, menu.resolution * 1, menu.resolution * 0);
    ctx.drawImage(textures.bottom, menu.resolution * 1, menu.resolution * 2);

    function drawIndividual(source, targetid) {
      var canvas = document.getElementById(targetid);
      canvas.width = canvas.height = menu.resolution;
      var ctx = canvas.getContext("2d");
      ctx.drawImage(source, 0, 0);
    }

    drawIndividual(textures.left, "texture-left");
    drawIndividual(textures.right, "texture-right");
    drawIndividual(textures.front, "texture-front");
    drawIndividual(textures.back, "texture-back");
    drawIndividual(textures.top, "texture-top");
    drawIndividual(textures.bottom, "texture-bottom");
  }

  renderTextures();

  var tick = 0.0;

  function render() {
    hideGui();

    if (!hideControls) {
      showGui();
    }

    tick += 0.0025 * menu.animationSpeed;

    var view = glm.mat4.create();
    var projection = glm.mat4.create();

    renderCanvas.width = renderCanvas.clientWidth;
    renderCanvas.height = renderCanvas.clientHeight;

    glm.mat4.lookAt(
      view,
      [0, 0, 0],
      [Math.cos(tick), Math.sin(tick * 0.555), Math.sin(tick)],
      [0, 1, 0]
    );

    var fov = (menu.fov / 360) * Math.PI * 2;
    glm.mat4.perspective(
      projection,
      fov,
      renderCanvas.width / renderCanvas.height,
      0.1,
      8
    );

    skybox.render(view, projection);

    setUrl();

    requestAnimationFrame(render);
  }

  render();
};

function generateRandomSeed() {
  return (Math.random() * 1000000000000000000).toString(36);
}
