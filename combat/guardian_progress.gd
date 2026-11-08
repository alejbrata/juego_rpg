class_name GuardianProgress
extends RefCounted

var affinity: int = 0:
	set(value):
		affinity = maxi(0, value)

func level(definition: GuardianData) -> int:
	var result := 1
	for i in range(definition.level_thresholds.size()):
		if affinity >= definition.level_thresholds[i]:
			result = i + 1
	return result
