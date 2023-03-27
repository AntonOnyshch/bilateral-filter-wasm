# Bilateral filter

[All additional information about Rust and WebAssembly you can find here](https://rustwasm.github.io/docs/wasm-pack/introduction.html)


## Result

<img width="1038" alt="bilateral-filter-example" src="https://user-images.githubusercontent.com/58116769/223050159-4e3decf6-c1f4-4dd7-be90-b9db2428082f.png">

## Regular and separate kernel speed test on filter size = 13



# Description

`Rust to WASM version of the filter has size ~17KB. The same version on WASM has size ~750B.`

This repo contains *two* versions of *.wasm.
First is regular filter with size ~750B
Second one uses unrolled loop/separate kernels with size ~26KB and it is much faster

I should note that separate kernel filter was not optimized with wasm-opt -O3. Test shown that optimized version is much slower than one which not.

[Bilateral filter written with rust is here](https://github.com/AntonOnyshch/bilateral-filter-rust).
[Bilateral filter written with typescript is here](https://github.com/AntonOnyshch/bilateral-filter).


### 🛠️ Build regular with `npm run build`
### 🛠️ Build separate kernel with `npm run build-fast`

### 🛠️ Test `npm run test`.
[http-server npm package](https://www.npmjs.com/package/http-server) should be installed.

### 🔬 Test

Open browser and put address which will be shown in visual studio terminal after run `npm run test`

## Useful links

* [About bilateral filter links/books/videos see my js repo README](https://github.com/AntonOnyshch/bilateral-filter)