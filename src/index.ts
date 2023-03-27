import { BFWASMAdapter } from './BFWASMAdapter.js';

let originalCvs: HTMLCanvasElement;
let filteredCvs: HTMLCanvasElement;

let originalCtx: CanvasRenderingContext2D;
let filteredCtx: CanvasRenderingContext2D;
let filteredImageData: ImageData;

let grayScaleArray: Uint8Array;

let sigmaSpatial: number;
let sigmaIntensity: number;

let bilateralFilter: BFWASMAdapter;

let width: string;
let height: string;

let pathToWasm: string;

window.addEventListener('DOMContentLoaded', (event) => {

    sigmaSpatial = +(document.getElementById('sigmaSpatial') as HTMLInputElement).value;
    sigmaIntensity = +(document.getElementById('sigmaIntensity') as HTMLInputElement).value;

    const image = document.createElement('img') as HTMLImageElement;

    image.addEventListener("load", async (e) => {
        width = image.width.toString();
        height = image.height.toString();

        originalCvs = document.getElementById("originalCvs") as HTMLCanvasElement;

        originalCvs.setAttribute('width', width);
        originalCvs.setAttribute('height', height);
        originalCvs.style.width = width;
        originalCvs.style.height = height;

        originalCtx = originalCvs.getContext("2d") as CanvasRenderingContext2D;

        originalCtx.drawImage(image, 0, 0);

        filteredCvs = document.getElementById("filteredCvs") as HTMLCanvasElement;

        filteredCvs.setAttribute('width', width);
        filteredCvs.setAttribute('height', height);
        filteredCvs.style.width = width;
        filteredCvs.style.height = height;

        filteredCtx = filteredCvs.getContext("2d") as CanvasRenderingContext2D;

        filteredImageData = filteredCtx.getImageData(0, 0, +width, +height);
        
        // Canvas have rgba chanels but i need only one since my image doesn't has colors
        grayScaleArray = getGrayscaleArray(originalCtx);

        pathToWasm = "../bin/bilateral-filter.wasm";

        await initWASM();
    });
    
    const selectTestImage = document.getElementById('testImages') as HTMLSelectElement;
    selectTestImage.onchange = e => {
        const imageName = (e.currentTarget as HTMLSelectElement).value;

        if(imageName.length > 0) {
            image.src = `../images/${imageName}`;
        }
    }

    const selectFilterType = document.getElementById('filterType') as HTMLSelectElement;
    selectFilterType.onchange = async e => {
        const value = (e.currentTarget as HTMLSelectElement).value;

        if(value === 'regular') {
            pathToWasm = "../bin/bilateral-filter.wasm";
            await initWASM();
        } else {
            pathToWasm = "../bin/bilateral-filter-fast.wasm";
            await initWASM();
        }
    }
});

async function initWASM() {
    bilateralFilter = new BFWASMAdapter(pathToWasm);
    bilateralFilter.setImage(+width, +height, grayScaleArray);
    await bilateralFilter.load();
    bilateralFilter.init(sigmaSpatial, sigmaIntensity);

    applyBilateralFilter();
}

function getGrayscaleArray(ctx: CanvasRenderingContext2D) {
    const imageData = ctx.getImageData(0, 0, ctx.canvas.width, ctx.canvas.height);
    const data = imageData.data;
    const grayScaleArray = new Uint8Array(data.byteLength / 4);

    // Took only "r" chanel
    for (let i = 0, j = 0; i < data.length; i+=4, j++) {
        grayScaleArray[j] = data[i];
    }

    return grayScaleArray;
}

function fillCanvasData(filteredArray: Uint8Array | Uint8ClampedArray, ctx: CanvasRenderingContext2D) {
    const data = new Uint32Array(filteredImageData.data.buffer);

    // Fill all 4 chanles with only one operation on abgr way
    for (let i = 0; i < filteredArray.length; i++) {
        data[i] = (255 << 24) + (filteredArray[i] << 16) + (filteredArray[i] << 8) + filteredArray[i];
    }

    ctx.putImageData(filteredImageData, 0, 0);
}

async function applyBilateralFilter() {
    const t0 = performance.now();
    const result = bilateralFilter.run();
    console.log(performance.now() - t0);
    fillCanvasData(result, filteredCtx);
}

(document.getElementById('sigmaSpatial') as HTMLInputElement).onchange = e => {
    sigmaSpatial = +(e.target as HTMLInputElement).value;
    document.getElementById('sigmaSpatialText').textContent = sigmaSpatial.toString();
    bilateralFilter.init(sigmaSpatial, sigmaIntensity);
    applyBilateralFilter();
}
(document.getElementById('sigmaIntensity') as HTMLInputElement).onchange = e => {
    sigmaIntensity = +(e.target as HTMLInputElement).value;
    document.getElementById('sigmaIntensityText').textContent = sigmaIntensity.toString();
    bilateralFilter.init(sigmaSpatial, sigmaIntensity);
    applyBilateralFilter();
}