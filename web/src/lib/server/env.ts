export function requireEnv(key: string): string {
	const val = process.env[key];
	if (!val) throw new Error(`${key} is required`);
	return val;
}
