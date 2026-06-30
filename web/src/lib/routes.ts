export const ROUTES = {
	home: "/",
	login: "/login",
	onboarding: "/onboarding",
	crm: "/crm",
	workspace: {
		new: "/w/new",
		detail: (id: string) => `/w/${id}`,
		sync: (id: string) => `/w/${id}/sync`,
		syncAccount: (workspaceId: string, accountId: string) =>
			`/w/${workspaceId}/sync/${accountId}`,
		observe: (id: string) => `/w/${id}/observe`,
		adjust: (id: string) => `/w/${id}/adjust`,
		strategize: (id: string) => `/w/${id}/strategize`,
	},
} as const;
