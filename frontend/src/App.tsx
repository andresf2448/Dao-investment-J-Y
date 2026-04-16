import { BrowserRouter } from "react-router-dom";
import { AppRouter } from "./app/router/AppRouter";
import { Provider } from "@/app/providers/RainboKit";

export default function App() {
  return (
    <Provider>
      <BrowserRouter>
        <AppRouter />
      </BrowserRouter>
    </Provider>
  );
}
