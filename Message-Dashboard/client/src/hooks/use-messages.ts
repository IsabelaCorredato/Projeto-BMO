import { useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@shared/routes";

export function useMessages() {
  const queryClient = useQueryClient();

  const query = useQuery({
    queryKey: [api.messages.list.path],
    queryFn: async () => {
      const res = await fetch(api.messages.list.path, { credentials: "include" });
      if (!res.ok) {
        throw new Error("Failed to fetch messages");
      }
      const data = await res.json();
      return api.messages.list.responses[200].parse(data);
    },
    // Refresh every 30 seconds automatically to keep dashboard alive
    refetchInterval: 30000,
  });

  const invalidate = () => {
    return queryClient.invalidateQueries({ queryKey: [api.messages.list.path] });
  };

  return {
    ...query,
    invalidate,
  };
}
