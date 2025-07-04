function setupPorts(app) {
  app.ports.saveToStorage.subscribe((payload) => {
    try {
      const { storageType, key, value } = payload;

      const data = JSON.stringify(value);

      if (storageType === "local") {
        localStorage.setItem(key, data);
      } else {
        sessionStorage.setItem(key, data);
      }
    } catch (e) {
      console.error("Ipê (save): Failed to save to storage.", e);
    }
  });

  app.ports.loadFromStorage.subscribe((payload) => {
    try {
      const { storageType, key } = payload;

      let data = null;
      if (storageType === "local") {
        data = localStorage.getItem(key);
      } else {
        data = sessionStorage.getItem(key);
      }

      let parsed = null;
      if (data !== null) {
        try {
          parsed = JSON.parse(data);
        } catch (parseError) {
          parsed = data;
          console.warn(
            "Ipê (load): Data is not valid JSON, treating as string:",
            parseError
          );
        }
      }

      app.ports.receiveStorageResult.send({ key, data: parsed });
    } catch (e) {
      console.error("Ipê (load): Failed to load from storage.", e);
      app.ports.receiveStorageResult.send({
        key: payload?.key || "",
        data: null,
      });
    }
  });

  app.ports.removeFromStorage.subscribe((payload) => {
    try {
      const { storageType, key } = payload;

      if (storageType === "local") {
        localStorage.removeItem(key);
      } else {
        sessionStorage.removeItem(key);
      }
    } catch (e) {
      console.error("Ipê (remove): Failed to remove from storage.", e);
    }
  });
}
