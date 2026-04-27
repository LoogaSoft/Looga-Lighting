#ifndef LOOGA_WIND_INCLUDED
#define LOOGA_WIND_INCLUDED

float4 _LoogaWindDirectionAndSpeed; 
float4 _LoogaWindTurbulence;        

// NEW: Added windInfluence parameter
float3 ApplyProceduralWind(float3 positionOS, float3 positionWS, float flutterMask, float windInfluence)
{
    float absoluteHeight = max(0.0, positionOS.y) * 0.1;
    float bendWeight = absoluteHeight * absoluteHeight; 

    float time = _Time.y * _LoogaWindDirectionAndSpeed.w;
    float phase = positionWS.x * 0.1 + positionWS.z * 0.1;
    float sway = sin(time + phase) * _LoogaWindTurbulence.x;

    float flutterPhase = positionWS.x * 2.0 + positionWS.y * 2.0 + positionWS.z * 2.0;
    float flutter = sin(_Time.y * _LoogaWindTurbulence.y + flutterPhase) * _LoogaWindTurbulence.z * flutterMask;

    float3 windDir = normalize(_LoogaWindDirectionAndSpeed.xyz);
    
    // NEW: Multiply the total movement by the material's influence slider
    float3 displacement = windDir * (sway + flutter) * bendWeight * windInfluence;

    displacement.y -= (sway * sway) * 0.5 * bendWeight * windInfluence;

    return positionOS + displacement;
}

// Calculates a 0 to 1 rolling wave based on the global wind direction and speed
float CalculateWindGust(float3 positionWS)
{
    float time = _Time.y * _LoogaWindDirectionAndSpeed.w;
    // We scale the phase by 0.1 to make the physical size of the gusts look massive across a field
    float phase = positionWS.x * 0.1 + positionWS.z * 0.1;
    
    // Normalizing a sine wave (-1 to 1) into a usable mask (0 to 1)
    return (sin(time + phase) * 0.5) + 0.5;
}

#endif