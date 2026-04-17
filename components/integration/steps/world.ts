import { setWorldConstructor, World, IWorldOptions, Before, After } from "@cucumber/cucumber";
import { chromium, Browser, Page } from "@playwright/test";

export class StackWorld extends World {
  browser?: Browser;
  page?: Page;

  constructor(options: IWorldOptions) {
    super(options);
  }
}

setWorldConstructor(StackWorld);

Before(async function (this: StackWorld) {
  this.browser = await chromium.launch();
  this.page = await this.browser.newPage();
});

After(async function (this: StackWorld) {
  if (this.page) {
    const buf = await this.page.screenshot();
    this.attach(buf, "image/png");
  }
  await this.browser?.close();
});
