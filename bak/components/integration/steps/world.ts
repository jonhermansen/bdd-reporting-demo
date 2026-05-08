// Kept for future use — none of the current synthetic scenarios drive a real
// browser, but Playwright stays wired up so we can add @browser-tagged
// scenarios later that take screenshots and attach them to the CTRF report
// (rich-reporting demo).
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

Before({ tags: "@browser" }, async function (this: StackWorld) {
  this.browser = await chromium.launch();
  this.page = await this.browser.newPage();
});

After({ tags: "@browser" }, async function (this: StackWorld) {
  if (this.page) {
    const buf = await this.page.screenshot();
    this.attach(buf, "image/png");
  }
  await this.browser?.close();
});
