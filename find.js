const fs = require("fs");
const path = require("path");

const findFileInDirectory = (directoryPath, fileNameToFind) => {
  const files = fs.readdirSync(directoryPath);

  for (const file of files) {
    const filePath = path.join(directoryPath, file);
    const stats = fs.statSync(filePath);

    if (stats.isFile() && file === fileNameToFind) {
      return filePath;
    } else if (stats.isDirectory()) {
      const foundFilePath = findFileInDirectory(filePath, fileNameToFind);
      if (foundFilePath) {
        return foundFilePath;
      }
    }
  }

  return null; // File not found
}

module.exports = {
  findFileInDirectory
}
