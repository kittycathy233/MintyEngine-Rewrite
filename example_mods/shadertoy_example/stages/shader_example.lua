-- ShaderToy Example Lua Script
-- This script demonstrates how to use ShaderToy shaders in Psych Engine

function onCreate()
    -- Create a simple ShaderToy shader
    local shaderCode = [[
        void mainImage( out vec4 fragColor, in vec2 fragCoord )
        {
            // Normalized pixel coordinates (from 0 to 1)
            vec2 uv = fragCoord/iResolution.xy;
            
            // Time varying pixel color
            vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));
            
            // Output to screen
            fragColor = vec4(col,1.0);
        }
    ]]

    -- Create the shader and get its ID
    shaderId = createShaderToy(shaderCode)
    if shaderId ~= nil then
        debugPrint("Created ShaderToy with ID: " .. shaderId)
        
        -- Apply the shader to the camera
        applyShaderToyToCamera(shaderId)
        debugPrint("Applied shader to camera")
    else
        debugPrint("Failed to create ShaderToy")
    end
end

function onUpdate()
    -- Update the shader every frame
    if shaderId ~= nil then
        updateShaderToy(shaderId)
    end
end

function onDestroy()
    -- Clean up the shader when the stage is destroyed
    if shaderId ~= nil then
        destroyShaderToy(shaderId)
        debugPrint("Destroyed ShaderToy")
    end
end
