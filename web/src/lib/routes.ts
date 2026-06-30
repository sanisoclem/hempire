export const ROUTES = {
  home: "/",
  login: "/login",
  onboarding: "/onboarding",
  crm: "/crm",
  workspace: {
    new: "/w/new",
    detail: (id: string) => `/w/${id}`,
  },
} as const;
