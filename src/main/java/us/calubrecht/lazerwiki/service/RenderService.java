package us.calubrecht.lazerwiki.service;

import org.apache.commons.lang3.time.StopWatch;
import org.apache.commons.text.StringEscapeUtils;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import us.calubrecht.lazerwiki.model.PageCache;
import us.calubrecht.lazerwiki.model.PageDesc;
import us.calubrecht.lazerwiki.model.RenderResult;
import us.calubrecht.lazerwiki.responses.PageData;
import us.calubrecht.lazerwiki.service.exception.PageWriteException;
import us.calubrecht.lazerwiki.service.renderhelpers.RenderContext;

import java.util.*;

import static us.calubrecht.lazerwiki.model.RenderResult.RENDER_STATE_KEYS.ID_SUFFIX;

@Service
public class RenderService {
    final Logger logger = LogManager.getLogger(getClass());

    @Autowired
    IMarkupRenderer renderer;

    @Autowired
    PageService pageService;

    @Autowired
    PageUpdateService pageUpdateService;

    @Autowired
    MacroService macroService;

    @Autowired
    SiteService siteService;

    public PageData getRenderedPage(String host, String sPageDescriptor, String userName) {
        StopWatch sw = StopWatch.createStarted();
        String site = siteService.getSiteForHostname(host);
        PageData d = pageService.getPageData(host, sPageDescriptor, userName);
        /*
          XXX:Could make these renderable templates;
         */
        if (!d.flags().userCanRead()) {
            return d;
        }
        if (d.flags().moved()) {
            RenderResult rendered = renderer.renderWithInfo(d.source(), host, site, sPageDescriptor, userName);
            PageData pd = new PageData(rendered.renderedText(), d.source(), d.title(), d.tags(), d.backlinks(), d.flags(), d.id(), d.revision());
            return pd;
        }
        if (!d.flags().exists()) {
            return d;
        }
        sw.split();
        long queryMillis = sw.getSplitTime();
        PageCache cachedPage = pageService.getCachedPage(host, sPageDescriptor);
        if (cachedPage != null && cachedPage.useCache) {
            RenderContext macroRenderContext = new RenderContext(host, site, sPageDescriptor, userName, renderer, new HashMap<>());
            String rendered = macroService.postRender(cachedPage.renderedCache, macroRenderContext);
            PageData pd = new PageData(rendered, cachedPage.source, d.title(), d.tags(), d.backlinks(), d.flags(), d.id(), d.revision());
            sw.stop();
            long totalMillis = sw.getTime();
            logger.info("Render " + sPageDescriptor + " took (" + totalMillis + "," + queryMillis + "," + (totalMillis-queryMillis) + ")ms (Total,Query,QueryCache)");
            return pd;
        }
        try {
            RenderContext renderContext = new RenderContext(host, site, sPageDescriptor, userName);
            renderContext.renderState().put(RenderResult.RENDER_STATE_KEYS.FOR_CACHE.name(), Boolean.TRUE);
            RenderResult cacheRender = renderer.renderWithInfo(d.source(), renderContext);
            RenderContext macroRenderContext = new RenderContext(host, site, sPageDescriptor, userName, renderer, new HashMap<>());
            String rendered = macroService.postRender(cacheRender.renderedText(), macroRenderContext);
            String source = pageService.adjustSource(d.source(), cacheRender);
            PageData pd = new PageData(rendered, source, d.title(), d.tags(), d.backlinks(), d.flags(), d.id(), d.revision());
            sw.stop();
            long totalMillis = sw.getTime();
            pageService.saveCache(host, sPageDescriptor, d.source(), cacheRender);
            logger.info("Render " + sPageDescriptor + " took (" + totalMillis + "," + queryMillis + "," + (totalMillis-queryMillis) + ")ms (Total,Query,Render)");
            return pd;
        }
        catch (Exception e) {
            logger.error("Render failed! host= " + host + " sPageDescriptor= " + sPageDescriptor + " user=" + userName + ".", e);
            String sanitizedSource =  StringEscapeUtils.escapeHtml4(d.source()).replaceAll("&quot;", "\"");

            return new PageData("<h1>Error</h1>\n<div>There was an error rendering this page! Please contact an admin, or correct the markup</div>\n<code>%s</code>".formatted(sanitizedSource),
                    d.source(), d.tags(), d.backlinks(),d.flags());

        }

    }

    public PageData getHistoricalRenderedPage(String host, String sPageDescriptor, long revision, String userName) {
        String site = siteService.getSiteForHostname(host);
        PageData d = pageService.getHistoricalPageData(host, sPageDescriptor, revision, userName);
        if (!d.flags().exists()) {
            return d;
        }
        if (!d.flags().userCanRead()) {
            return d;
        }
        try {
            RenderContext context = new RenderContext(host, site, sPageDescriptor, userName);
            context.renderState().put(ID_SUFFIX.name(), "_historyView");
            RenderResult rendered = renderer.renderWithInfo(d.source(), context);
            PageData pd = new PageData(rendered.renderedText(), d.source(), d.title(), d.tags(), d.backlinks(), d.flags());
            return pd;
        }
        catch (Exception e) {
            logger.error("Render failed! host= " + host + " sPageDescriptor= " + sPageDescriptor + " user=" + userName + ".", e);
            String sanitizedSource =  StringEscapeUtils.escapeHtml4(d.source()).replaceAll("&quot;", "\"");

            return new PageData("<h1>Error</h1>\n<div>There was an error rendering this page! Please contact an admin, or correct the markup</div>\n<code>%s</code>".formatted(sanitizedSource),
                    d.source(), d.tags(), d.backlinks(),d.flags());
        }
    }

    @SuppressWarnings("unchecked")
    public void savePage(String host, String sPageDescriptor,String text, List<String> tags, long revision, boolean force, String userName) throws PageWriteException {
        String site = siteService.getSiteForHostname(host);
        RenderContext renderContext = new RenderContext(host, site, sPageDescriptor, userName);
        renderContext.renderState().put(RenderResult.RENDER_STATE_KEYS.FOR_CACHE.name(), Boolean.TRUE);
        RenderResult res = renderer.renderWithInfo(text, renderContext);
        Collection<String> links = (Collection<String>)res.renderState().getOrDefault(RenderResult.RENDER_STATE_KEYS.LINKS.name(), Collections.emptySet());
        Collection<String> images = (Collection<String>)res.renderState().getOrDefault(RenderResult.RENDER_STATE_KEYS.IMAGES.name(), Collections.emptySet());
        pageUpdateService.savePage(host, sPageDescriptor, revision, text, tags, links, images, res.getTitle(), userName, force);
        pageService.saveCache(host, sPageDescriptor, text, res);
    }

    public PageData previewPage(String host, String sPageDescriptor, String text, String userName) {
        StopWatch sw = StopWatch.createStarted();
        String site = siteService.getSiteForHostname(host);
        try {
            RenderContext context = new RenderContext(host, site, sPageDescriptor+"<preview>", userName);
            context.renderState().put(ID_SUFFIX.name(), "_previewPage");
            PageData pd = new PageData(renderer.renderToString(text, context), text, null, null, null);
            sw.stop();
            long totalMillis = sw.getTime();
            logger.info("Render preview for " + sPageDescriptor + " took " + totalMillis + "ms");
            return pd;
        }
        catch (Exception e) {
            sw.stop();
            logger.error("Render preview failed! host= " + host + " sPageDescriptor= " + sPageDescriptor + " user=" + userName + ".", e);
            String sanitizedSource =  StringEscapeUtils.escapeHtml4(text).replaceAll("&quot;", "\"");

            return new PageData("<h1>Error</h1>\n<div>There was an error rendering this page! Please contact an admin, or correct the markup</div>\n<code>%s</code>".formatted(sanitizedSource),
                    text, null, null, null);

        }

    }
}
