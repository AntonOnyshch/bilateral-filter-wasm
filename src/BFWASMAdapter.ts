/**
 * Adapter class for hiding all JS/WASM logic
 */
export class BFWASMAdapter {
    private static MAX_KERNEL_SIZE = 15;
    private static INTENSITY_LUT_RANGE = 256;

    // Our LUT will contain 32f values so we need multiply all constants to 4
    private static INTENSITY_LUT_SIZE = BFWASMAdapter.INTENSITY_LUT_RANGE * Float32Array.BYTES_PER_ELEMENT;
    private static SPATIAL_LUT_SIZE = BFWASMAdapter.MAX_KERNEL_SIZE * BFWASMAdapter.MAX_KERNEL_SIZE * Float32Array.BYTES_PER_ELEMENT;

    private path: string;

    private exports: any;

    private pageSize: number;
    private memory: WebAssembly.Memory;

    private imageWidth: number;
    private imageHeight: number;
    private imageSize: number;
    private inputData: Uint8Array;

    private inputImageMemory: Uint8Array;
    private outputImageMemory: Uint8Array;

    constructor(path: string) {
        this.path = path;
    }

    public setImage(width: number, height: number, inputData: Uint8Array) {
        this.imageWidth = width;
        this.imageHeight = height;
        this.imageSize = width * height;
        this.inputData = inputData;
    }

    public async load() {
        this.createMemory();

        const wasm = await fetch(this.path);
        const source = await WebAssembly.instantiateStreaming(wasm, {js: {memory: this.memory }, math: {exp: Math.exp}, console: {log: console.log}});
        this.exports = source.instance.exports;

        this.exports.setSize(BFWASMAdapter.INTENSITY_LUT_RANGE, BFWASMAdapter.MAX_KERNEL_SIZE, this.imageWidth, this.imageHeight);
    }

    public init(sigmaSpatial: number, sigmaIntensity: number) {
        this.exports.init(sigmaSpatial, sigmaIntensity);
    }

    public run(): Uint8Array {
        this.exports.run();

        return this.outputImageMemory;
    }

    private createMemory() {
        this.pageSize = Math.ceil(
            (BFWASMAdapter.INTENSITY_LUT_SIZE + BFWASMAdapter.SPATIAL_LUT_SIZE + (this.imageSize) + (this.imageSize)) / 64000
        );

        this.memory = new WebAssembly.Memory({initial: this.pageSize});

        this.setInputDataToMemory();
        this.getOutputMemoryToData();

        this.inputImageMemory.set(this.inputData);
    }

    private setInputDataToMemory() {
        this.inputImageMemory = new Uint8Array(this.memory.buffer, BFWASMAdapter.INTENSITY_LUT_SIZE + BFWASMAdapter.SPATIAL_LUT_SIZE, this.imageSize);
    }

    private getOutputMemoryToData() {
        this.outputImageMemory = new Uint8Array(this.memory.buffer, BFWASMAdapter.INTENSITY_LUT_SIZE + BFWASMAdapter.SPATIAL_LUT_SIZE + this.imageSize, this.imageSize);
    }
}