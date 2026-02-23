export const getMetaContent = (field) => {
  const element = document.querySelector(`meta[name=${field}]`);

  if (element) {
    return element.getAttribute("content");
  } else {
    return null;
  }
};
