import { type MessagesResponse } from "@shared/schema";

export interface IStorage {
  getMessages(): Promise<MessagesResponse>;
}

export class ApiStorage implements IStorage {
  async getMessages(): Promise<MessagesResponse> {
    try {
      const response = await fetch("https://nonprivileged-jamie-bottomless.ngrok-free.dev/messages", {
        headers: {
          "Authorization": "Bearer bmo-local-123",
          "ngrok-skip-browser-warning": "true"
        }
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch messages: ${response.statusText}`);
      }

      const data = await response.json();
      return data as MessagesResponse;
    } catch (error) {
      console.error("Ngrok endpoint failed, returning mock data:", error);
      // Return mock data so the dashboard still renders if ngrok is offline
      return {
        count: 5,
        data: [
          { id: 1, source: "mock-app", text: "ngrok is offline", createdAt: new Date().toISOString() },
          { id: 2, source: "mock-probe", text: "start your ngrok tunnel", createdAt: new Date().toISOString() },
          { id: 3, source: "mock-esp32", text: "waiting for connection", createdAt: new Date().toISOString() },
          { id: 4, source: "mock-app", text: "fallback data", createdAt: new Date().toISOString() },
          { id: 5, source: "mock-probe", text: "dashboard ready", createdAt: new Date().toISOString() }
        ]
      };
    }
  }
}

export const storage = new ApiStorage();
