(module
    (export "init" (func $init))
    (export "setSize" (func $setSize))
    (export "run" (func $run))
    (export "calcKSize" (func $calculate_kernel_size))
    (import "math" "exp" (func $exp (param f32)(result f32)))
    (import "console" "log" (func $log (param v128)))
    (import "js" "memory" (memory 1))

    (global $spatial_lut_offset (mut i32) (i32.const 0))
    (global $input_image_offset (mut i32) (i32.const 0))
    (global $output_image_offset (mut i32) (i32.const 0))

    (global $kernel_size (mut i32) (i32.const 0))

    (global $half_kernel_size (mut i32) (i32.const 0))
    (global $minus_half_kernel_size (mut i32) (i32.const 0))

    (global $width (mut i32) (i32.const 0))
    (global $height (mut i32) (i32.const 0))
    (global $image_size (mut i32) (i32.const 0))

    (func $init (param $spatial f32)(param $intensity f32)
        (global.set $kernel_size (call $calculate_kernel_size (local.get $spatial)))

        (global.set $half_kernel_size (i32.trunc_f32_u (f32.floor (f32.div (f32.const 2 (f32.convert_i32_u (global.get $kernel_size)))))))
        (global.set $minus_half_kernel_size (i32.mul (i32.const -1 (global.get $half_kernel_size))))

        (call $calculateIntensityLUT (local.get $intensity))
        (call $calculateGaussianSpatialLUT (local.get $spatial) (global.get $half_kernel_size ))
    )

    (func $setSize (param $intensity i32) (param $spatial i32) (param $width i32) (param $height i32)
        (global.set $width (local.get $width))
        (global.set $height (local.get $height))

        (global.set $image_size (i32.mul (local.get $width (local.get $height))))
        (global.set $spatial_lut_offset (i32.mul (local.get $intensity (i32.const 4))))

        (global.set $input_image_offset (i32.add (global.get $spatial_lut_offset (i32.mul (i32.const 4 (i32.mul (local.get $spatial (local.get $spatial))))))))
        (global.set $output_image_offset (i32.add (global.get $input_image_offset (i32.mul (local.get $width (local.get $height))))))
    )

    (func $calculate_kernel_size (param $spatial f32) (result i32)
        (local $kernel_size i32)
        (local $is_odd i32)
        (local $odd_kernel_size i32)
        (local $kernel_minus_one i32)

        (local.set $kernel_size (i32.trunc_f32_u (f32.floor (f32.mul (f32.const 1.95 (local.get $spatial))))))

        (local.set $is_odd (i32.rem_u (i32.const 2 (local.get $kernel_size))))

        (local.set $kernel_minus_one (i32.sub (i32.const 1 (local.get $kernel_size))))

        (f32.max (f32.const 3 (f32.convert_i32_u (select (local.get $kernel_size) (local.get $kernel_minus_one) (local.get $is_odd)))))
        i32.trunc_f32_u
    )

    ;;
    ;;Look Up Table for Intensity function
    ;;@param {number} sigma Pixel intensity range. 
    ;;As the range parameter σr increases, the bilateral filter gradually approaches Gaussian convolution more closely
    ;;because the range Gaussian widens and flattens, which means that it becomes 
    ;;nearly constant over the intensity interval of the image.
    ;;
    (func $calculateIntensityLUT (param $sigma f32)
        (local $intensity f32) (local $intensitySquare f32) (local $i i32) (local $memory_offset i32) (local $lut_value f32)

        (local.set $intensity ( call $normalized (local.get $sigma)))
        (local.set $intensitySquare (call $getSquare (local.get $sigma)))

        loop $loop

            (local.set $lut_value (call $lut_expression (local.get $intensity) (local.get $intensitySquare) (f32.convert_i32_u (local.get $i)) ))
            (f32.store (local.get $memory_offset) (local.get $lut_value))
            
            ;; $i++, 
            (local.set $i (i32.add (i32.const 1 (local.get $i))))

            ;; memory_offset+=4
            (local.set $memory_offset (i32.add (i32.const 4 (local.get $memory_offset))))

            (i32.lt_s (local.get $i) (i32.const 256))
            br_if $loop
        end
    )

    (func $calculateGaussianSpatialLUT (param $sigma f32) (param $half_kernel_size i32)
        (local $memory_offset i32)
        (local $spatial f32)
        (local $spatialSquare f32)
        (local $i i32)
        (local $j i32)
        (local $minus_kernel_size i32)
        (local $hypot_value f32)
        (local $lut_value f32)

        (local.set $spatial (call $normalized (local.get $sigma)))
        (local.set $spatialSquare (call $getSquare (local.get $sigma)))

        (local.set $memory_offset (global.get $spatial_lut_offset))

        (local.set $minus_kernel_size (i32.mul (local.get $half_kernel_size (i32.const -1)) ))

        (local.set $i (local.get $minus_kernel_size))

        (loop $i_loop

            (local.set $j (local.get $minus_kernel_size))

            (loop $j_loop
                (local.set $hypot_value (call $hypot (local.get $i) (local.get $j)))

                (local.set $lut_value (call $lut_expression (local.get $spatial) (local.get $spatialSquare) (local.get $hypot_value) ))

                (f32.store (local.get $memory_offset) (local.get $lut_value))

                (local.set $j (i32.add (local.get $j (i32.const 1))))

                (local.set $memory_offset (i32.add (local.get $memory_offset (i32.const 4))))

                (i32.le_s (local.get $j) (local.get $half_kernel_size) )
                br_if $j_loop
            )

            (local.set $i (i32.add (local.get $i (i32.const 1))))

            (i32.le_s (local.get $i) (local.get $half_kernel_size) )
            br_if $i_loop
        )
    )

    ;; Hypotenuse. Sqrt(a^2 + b^2)
    (func $hypot (param $a i32)(param $b i32) (result f32)
        (local $ab i32)

        (local.set $ab (i32.mul (local.get $a (local.get $a))))
        (i32.add (local.get $ab (i32.mul (local.get $b (local.get $b)))))
        
        f32.convert_i32_s
        f32.sqrt
    )

    ;; 1 / ((PI * 2) * (sigma^2))
    (func $normalized (param $sigma f32) (result f32)
        f32.const 1
        (f32.mul (f32.const 6.2831853071 (f32.mul (local.get $sigma (local.get $sigma)))))
        f32.div
    )

    ;; 2 * (sigma^2)
    (func $getSquare (param $sigma f32) (result f32)
        (f32.mul (f32.const 2 (f32.mul (local.get $sigma (local.get $sigma)))))
    )

    ;; sigma * Math.exp(-(Math.pow(distance, 2)) / sigmaSquare);
    (func $lut_expression (param $sigma f32) (param $sigma_square f32) (param $distance f32) (result f32)
        (f32.div (f32.neg (f32.mul (local.get $distance (local.get $distance))) (local.get $sigma_square)))
        call $exp
        local.get $sigma
        f32.mul
    )

    (func $run
        (local $end_width i32)
        (local $end_height i32)

        (local $pixel i32)

        (local $height_index i32)
        (local $half_kernel_size_stride i32)
        (local $central_pixel_index i32)

        (local $i i32)
        (local $j i32)

        (local $startHeight i32)
        (local $top_left_kernel_index i32)

        (local.set $end_width (i32.sub (global.get $half_kernel_size (global.get $width))))
        (local.set $end_height (i32.sub (global.get $half_kernel_size (global.get $height))))
        (local.set $i (global.get $half_kernel_size))

        (local.set $half_kernel_size_stride (i32.mul (global.get $half_kernel_size (global.get $width))))

        (local.set $height_index (i32.add (global.get $input_image_offset (local.get $half_kernel_size_stride))))

        (loop $height_loop
            (local.set $j (global.get $half_kernel_size))

            (local.set $startHeight (i32.sub (local.get $half_kernel_size_stride (local.get $height_index))))

            (loop $width_loop
                (local.set $central_pixel_index (i32.add (local.get $j (local.get $height_index))))
                (local.set $top_left_kernel_index (i32.add (local.get $startHeight (i32.sub (global.get $half_kernel_size (local.get $j))))))
                
                (local.set $pixel (call $run_kernel (i32.load8_u (local.get $central_pixel_index)) (local.get $top_left_kernel_index)))

                (i32.store8 (i32.add (global.get $image_size (local.get $central_pixel_index))) (local.get $pixel))

                (local.set $j (i32.add (i32.const 1 (local.get $j))))

                (i32.lt_u (local.get $j) (local.get $end_width))
                br_if $width_loop
            
            )
            (local.set $height_index (i32.add (local.get $height_index (global.get $width))))
            (i32.lt_u (local.tee $i (i32.add (i32.const 1 (local.get $i)))) (local.get $end_height))
            br_if $height_loop
        )
    )

    (func $run_kernel (param $central_pixel i32)(param $start_position i32)(result i32)
        (local $sum_weight f32)
        (local $normalize_weight f32)
        (local $weight f32)
        (local $counter i32)
        (local $nearby_pixel i32)
        (local $intensity_lut_value f32)
        (local $i i32)
        (local $j i32)

        (local.set $counter (global.get $spatial_lut_offset))

        (loop $height_loop
            
            (local.set $j (i32.const 0))

            (loop $width_loop
                
                (i32.mul (i32.const 4) (i32.trunc_f32_u (f32.abs (f32.convert_i32_s (i32.sub (local.get $central_pixel ( local.tee $nearby_pixel (i32.load8_u (i32.add (local.get $j (local.get $start_position)))))))))))
                f32.load
                local.set $intensity_lut_value

                (local.set $sum_weight (f32.add (
                    local.get $sum_weight 
                    (f32.mul (f32.convert_i32_u (local.get $nearby_pixel)) (local.tee $weight (f32.mul (f32.load (local.get $counter)) (local.get $intensity_lut_value))))
                )))

                (local.set $normalize_weight (f32.add (local.get $weight (local.get $normalize_weight))))

                (local.set $counter (i32.add (local.get $counter (i32.const 4))))

                (i32.lt_u (local.tee $j (i32.add (i32.const 1 (local.get $j)))) (global.get $kernel_size))
                br_if $width_loop
            )

            (local.set $start_position (i32.add (global.get $width (local.get $start_position))))

            (i32.lt_u (local.tee $i (i32.add (i32.const 1 (local.get $i)))) (global.get $kernel_size))
            br_if $height_loop
        )

        (i32.trunc_f32_u (f32.div (local.get $normalize_weight (local.get $sum_weight))))
    )
)