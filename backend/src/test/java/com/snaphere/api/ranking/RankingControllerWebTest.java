package com.snaphere.api.ranking;

import com.snaphere.api.common.error.GlobalExceptionHandler;
import com.snaphere.api.common.security.CurrentUserProvider;
import com.snaphere.api.common.web.TraceIdFilter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class RankingControllerWebTest {

    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        RankingRepository repository = mock(RankingRepository.class);
        CurrentUserProvider users = mock(CurrentUserProvider.class);
        when(users.optional(any())).thenReturn(Optional.empty());

        mvc = MockMvcBuilders
                .standaloneSetup(new RankingController(new RankingService(repository), users))
                .setControllerAdvice(new GlobalExceptionHandler())
                .addFilters(new TraceIdFilter())
                .build();
    }

    @Test
    void missingScopeReturnsCommon400() throws Exception {
        mvc.perform(get("/api/v1/rankings/places").param("period", "WEEKLY"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.error.code").value("COMMON_400"));
    }
}
