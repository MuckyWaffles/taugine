#version 330 core
out vec4 FragColor;

in vec3 Normal;
in vec3 FragPos;

uniform vec3 objectColor;
uniform vec3 lightColor;
uniform vec3 lightPos;

void main() {

	// Normal ambient light, I was messing around with it a bit and
	// found something I liked better so I'm not using this
	//float ambientStrength = 0.2;
	
	// Ambient light
	float dist = distance(lightPos, FragPos) + 1;
	float ambientStrength = clamp(0.1 + 10/(dist*dist), 0.0, 1.0);
	
	vec3 ambient = ambientStrength * lightColor;
	
	// Diffuse light
	vec3 norm = normalize(Normal);
	vec3 lightDir = normalize(lightPos - FragPos);
	float diff = max((dot(norm, lightDir) * 0.9) + 0.1, 0.0);
	vec3 diffuse = diff * lightColor;
	
	vec3 result = (ambient + diffuse) * objectColor;
    FragColor = vec4(result, 1.0);
}
