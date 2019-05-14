//====================================================================================================
// Filename:	ShadowMapping.fx
// Created by:	Peter Chan
// Description:	Shader performing shadow mapping.
//====================================================================================================

//====================================================================================================
// Constant Buffers
//====================================================================================================

cbuffer ConstantBuffer : register( b0 )
{
	matrix world;
	matrix wvp;
	matrix wvpLight;
	vector cameraPosition;
	vector lightDirection;
	vector lightAmbient;
	vector lightDiffuse;
	vector lightSpecular;
	vector materialAmbient;
	vector materialDiffuse;
	vector materialSpecular;
	vector materialEmissive;
	float materialPower;
	float displacementScale;
};

Texture2D diffuseMap : register(t0);
Texture2D specularMap : register(t1);
Texture2D normalMap : register(t2);
Texture2D displacementMap : register(t3);
Texture2D depthMap : register(t4);
SamplerState textureSampler : register(s0);
SamplerState depthSampler : register(s1);

//====================================================================================================
// Structs
//====================================================================================================

struct VS_INPUT
{
	float4 position	: POSITION;
	float3 normal	: NORMAL;
	float3 tangent	: TANGENT;
	float4 color	: COLOR;
	float2 texCoord	: TEXCOORD;
};

//----------------------------------------------------------------------------------------------------

struct VS_OUTPUT
{
	float4 position		: SV_POSITION;
	float3 normal		: NORMAL;
	float3 tangent		: TANGENT;
	float3 binormal		: BINORMAL;
	float3 dirToLight	: TEXCOORD0;
	float3 dirToView	: TEXCOORD1;
	float2 texCoord		: TEXCOORD2;
	float4 depthCoord	: TEXCOORD3;
};

//====================================================================================================
// Vertex Shader
//====================================================================================================

VS_OUTPUT VS(VS_INPUT input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	float displacement = displacementMap.SampleLevel(textureSampler, input.texCoord, 0).x;
	float4 position = input.position + (float4(input.normal, 0.0f) * displacementScale * displacement);

	float4 posWorld = mul(position, world);
	float4 posProj = mul(position, wvp);
	
	float3 normal = mul(float4(input.normal, 0.0f), world).xyz;
	float3 tangent = mul(float4(input.tangent, 0.0f), world).xyz;
	float3 binormal = cross(normal, tangent);
	
	float3 dirToLight = -normalize(lightDirection.xyz);
	float3 dirToView = normalize(cameraPosition.xyz - posWorld.xyz);

	output.position = posProj;
	output.normal = normal;
	output.tangent = tangent;
	output.binormal = binormal;
	output.dirToLight = dirToLight;
	output.dirToView = dirToView;
	output.texCoord = input.texCoord;
	output.depthCoord = mul(position, wvpLight);
	
	return output;
}

//====================================================================================================
// Pixel Shader
//====================================================================================================

float4 PS(VS_OUTPUT input) : SV_Target
{
	// Sample normal from normal map
	float4 normalColor = normalMap.Sample(textureSampler, input.texCoord);
	float3 sampledNormal = float3((2.0f * normalColor.xy) - 1.0f, normalColor.z);

	// Transform to world space
	float3 t = normalize(input.tangent);
	float3 b = normalize(input.binormal);
	float3 n = normalize(input.normal);
	float3x3 tbn = float3x3(t, b, n);
	float3 normal = mul(sampledNormal, tbn);

	float3 dirToLight = normalize(input.dirToLight);
	float3 dirToView = normalize(input.dirToView);
	
	// Ambient
	float4 ambient = lightAmbient * materialAmbient;
	
	// Diffuse
	float d = saturate(dot(dirToLight, normal));
	float4 diffuse = d * lightDiffuse * materialDiffuse;
		
	// Specular
	float3 h = normalize((dirToLight + dirToView) * 0.5f);
	float s = saturate(dot(h, normal));
	float4 specular = pow(s, materialPower) * lightSpecular * materialSpecular;

	float4 diffuseColor = diffuseMap.Sample(textureSampler, input.texCoord);
	float4 specularColor = specularMap.Sample(textureSampler, input.texCoord).rrrr;
	
	float4 finalColor = ((ambient + diffuse) * diffuseColor) * 0.35f;
	if (input.depthCoord.w > 0.0f)
	{
		float3 depthCoord = input.depthCoord.xyz / input.depthCoord.w;
		float pixelDepth = depthCoord.z;
		//float2 depthUV = (depthCoord.xy + 1.0f) * 0.5f;
		//depthUV.y = 1.0f - depthUV.y;
		//float sampledDepth = depthMap.Sample(depthSampler, depthUV).r + 0.001f;
		float sampledDepth = depthMap.Sample(depthSampler, depthCoord).r + 0.001f;
		if (pixelDepth < sampledDepth)
		{
			finalColor = ((ambient + diffuse) * diffuseColor) + (specular * specularColor);
		}
	}
	return finalColor;
}
